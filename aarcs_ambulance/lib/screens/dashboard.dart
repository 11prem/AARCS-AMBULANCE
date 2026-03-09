// lib/screens/dashboard.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'route_navigation.dart';
import 'history_screen.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/priority_model.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart' show flutterLocalNotificationsPlugin, navigatorKey;

class DashboardScreen extends StatefulWidget {
  final String ambulanceId;
  final VoidCallback onToggleTheme;

  const DashboardScreen({
    super.key,
    required this.ambulanceId,
    required this.onToggleTheme,
  });

  @override
  State createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _justificationController =
  TextEditingController();

  StreamSubscription<DatabaseEvent>? _assignedRequestSubscription;
  bool _isNavigatingToRequest = false;
  // ignore: unused_field
  bool _isButtonPressed = false;
  bool _isLoading = false;
  Position? _currentPosition;
  List<Map<String, dynamic>> nearbyHospitals = [];
  Timer? _debounce;
  List<dynamic> _searchSuggestions = [];
  late TabController _tabController;

  Map<String, dynamic>? _selectedHospital;

  final String _googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  final List<String> _allowedNameKeywords = [
    'hospital',
    'multi specialty',
    'multi speciality',
    'general hospital',
    'medical college',
    'government hospital',
    'emergency',
    'trauma center',
    'trauma centre',
    'super specialty',
    'super speciality',
    'medical center',
    'medical centre',
    'healthcare center',
    'healthcare centre',
    'bethesda hospital and child care centre',
    'annai theresa hospital'
  ];

  final List<String> _excludeKeywords = [
    'dental',
    'ortho',
    'orthopedic',
    'orthopedic',
    'skin',
    'dermatology',
    'cosmetic',
    'beauty',
    'eye',
    'optical',
    'vision',
    'lasik',
    'ent',
    'ear nose throat',
    'fertility',
    'ivf',
    'care',
    'psychiatry',
    'psychology',
    'mental health',
    'physiotherapy',
    'rehab',
    'rehabilitation',
    'ayurveda',
    'homeopathy',
    'diagnostic',
    'lab',
    'pathology',
    'pharmacy',
    'medical store',
    'clinic',
    'polyclinic',
    'veterinary',
    'pet',
    'nursing home',
    'derby',
    'medicity'
  ];

  final List<String> _hospitalKeywords = [
    'hospital',
    'speciality',
    'emergency',
    'medical center',
    'medical centre',
    'healthcare',
    'bethesda hospital',
    'annai theresa'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshLocationAndHospitals();
    _listenForAssignedRequest();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForExistingRequest();
    });
  }

  Future<void> _refreshLocationAndHospitals() async {
    setState(() => _isLoading = true);
    await _determinePositionWithFallback();
    await _fetchNearbyHospitals();
    setState(() => _isLoading = false);
  }

  Future<void> _determinePositionWithFallback() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('📍 Location service enabled: $serviceEnabled');

      if (!serviceEnabled) {
        print('❌ Location services disabled');
        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      print('📍 Current permission: $permission');

      if (permission == LocationPermission.denied) {
        print('📍 Requesting permission...');
        permission = await Geolocator.requestPermission();
        print('📍 Permission after request: $permission');
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Permission permanently denied');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied')),
        );
        return;
      }

      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        print('📍 Got current position: ${pos.latitude}, ${pos.longitude}');
        _currentPosition = pos;
      } catch (e) {
        print('❌ Error getting current position: $e');
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          print('📍 Using last known position: ${last.latitude}, ${last.longitude}');
          _currentPosition = last;
        } else {
          print('❌ No last known position available');
        }
      }
    } catch (e) {
      print('❌ Error determining position: $e');
    }
  }

  bool _isValidHospital(String name, List<String> types) {
    final String nameLower = name.toLowerCase();
    for (String excludeKeyword in _excludeKeywords) {
      if (nameLower.contains(excludeKeyword.toLowerCase())) return false;
    }
    bool nameMatch = _allowedNameKeywords.any((kw) => nameLower.contains(kw.toLowerCase()));
    bool typeMatch = types.any((type) =>
    type.contains('hospital') || type.contains('health') || type.contains('establishment'));
    return nameMatch || (typeMatch && !nameLower.contains('clinic'));
  }

  Future<Map<String, dynamic>?> _getPlaceDetails(String placeId) async {
    final detailsUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
            '?place_id=$placeId'
            '&fields=opening_hours,current_opening_hours'
            '&key=$_googleApiKey');
    try {
      final resp = await http.get(detailsUrl);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['status'] == 'OK' && data['result'] != null) {
          return data['result'];
        }
      }
    } catch (e) {
      debugPrint('Error fetching place details for $placeId: $e');
    }
    return null;
  }

  Map<String, dynamic> _getOpeningStatus(
      Map<String, dynamic>? openingHours, Map<String, dynamic>? currentOpeningHours) {
    if (currentOpeningHours != null && currentOpeningHours.containsKey('open_now')) {
      return {
        'isOpen': currentOpeningHours['open_now'] as bool,
        'isKnown': true,
      };
    }
    if (openingHours != null && openingHours.containsKey('open_now')) {
      return {
        'isOpen': openingHours['open_now'] as bool,
        'isKnown': true,
      };
    }
    return {'isOpen': false, 'isKnown': false};
  }

  Future<void> _fetchNearbyHospitals() async {
    print('🔑 API Key loaded: ${_googleApiKey.substring(0, 5)}...'); // Partial key for debugging
    print('📍 Current position: $_currentPosition');
    print('📍 Fetching hospitals with key: $_googleApiKey');
    print('📍 Position: $_currentPosition');

    nearbyHospitals = [];

    if (_currentPosition == null) {
      print('❌ Current position is null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location not available to find hospitals")),
      );
      return;
    }

    final placesUrl =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?'
        'location=${_currentPosition!.latitude},${_currentPosition!.longitude}'
        '&radius=10000'
        '&type=hospital'
        '&key=$_googleApiKey';

    print('📡 Making API call to: $placesUrl');

    try {
      setState(() => _isLoading = true);
      final resp = await http.get(Uri.parse(placesUrl));

      print('📡 Response status code: ${resp.statusCode}');

      if (resp.statusCode != 200) {
        print('❌ Places API error: ${resp.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to fetch hospitals. Status: ${resp.statusCode}"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Print first 500 chars of response body for debugging
      print('📡 Response body preview: ${resp.body.length > 500 ? resp.body.substring(0, 500) + '...' : resp.body}');

      final data = json.decode(resp.body);
      print('📍 API Status: ${data['status']}');
      print('📍 Error message: ${data['error_message'] ?? 'None'}');

      if (data['status'] != 'OK') {
        print('❌ API returned error status: ${data['status']}');
        if (data['status'] == 'REQUEST_DENIED') {
          print('❌ REQUEST_DENIED - This usually means:');
          print('   1. API key is invalid');
          print('   2. Places API is not enabled');
          print('   3. API key has restrictions');
        } else if (data['status'] == 'ZERO_RESULTS') {
          print('📍 No hospitals found in this area');
        }
        // Don't return here - let the function continue with empty results
      }

      final results = (data['results'] as List?) ?? [];
      print('📍 Raw results count: ${results.length}');

      final List<Map<String, dynamic>> hospitals = [];

      for (var place in results) {
        final geometry = place['geometry'];
        final loc = geometry?['location'];
        if (loc == null) continue;

        final num? latNum = loc['lat'];
        final num? lngNum = loc['lng'];
        if (latNum == null || lngNum == null) continue;

        final double lat = latNum.toDouble();
        final double lng = lngNum.toDouble();
        final String name = (place['name'] ?? '').toString();
        final String placeId = (place['place_id'] ?? '').toString();
        final String vicinity = (place['vicinity'] ?? '').toString();
        final double rating =
        (place['rating'] is num) ? (place['rating'] as num).toDouble() : 0.0;

        final dynamic typesDynamic = place['types'];
        final List<String> types = [];
        if (typesDynamic is List) {
          for (var t in typesDynamic) {
            if (t != null) types.add(t.toString().toLowerCase());
          }
        }

        print('📍 Processing hospital: $name');
        print('   - Types: $types');

        if (!_isValidHospital(name, types)) {
          print('   - ❌ Filtered out by _isValidHospital');
          continue;
        }
        print('   - ✅ Passed validation');

        final double distanceMeters = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          lat,
          lng,
        );
        print('   - Distance: ${(distanceMeters / 1000).toStringAsFixed(2)} km');

        Map<String, dynamic> openingStatus = {'isOpen': false, 'isKnown': false};

        if (place['opening_hours'] != null) {
          openingStatus = _getOpeningStatus(
              Map<String, dynamic>.from(place['opening_hours']), null);
        } else {
          final placeDetails = await _getPlaceDetails(placeId);
          if (placeDetails != null) {
            openingStatus = _getOpeningStatus(
              placeDetails['opening_hours'] != null
                  ? Map<String, dynamic>.from(placeDetails['opening_hours'])
                  : null,
              placeDetails['current_opening_hours'] != null
                  ? Map<String, dynamic>.from(placeDetails['current_opening_hours'])
                  : null,
            );
          }
        }

        hospitals.add({
          'name': name,
          'place_id': placeId,
          'address': vicinity,
          'lat': lat,
          'lng': lng,
          'rating': rating,
          'distance_m': distanceMeters,
          'distance_text': (distanceMeters / 1000).toStringAsFixed(2) + ' km',
          'isOpen': openingStatus['isOpen'],
          'isOpeningStatusKnown': openingStatus['isKnown'],
        });
      }

      print('📍 Hospitals after validation: ${hospitals.length}');

      if (hospitals.isEmpty) {
        print('📍 No hospitals passed validation');
        setState(() => nearbyHospitals = []);
        return;
      }

      hospitals.sort((a, b) => (a['distance_m'] as double).compareTo(b['distance_m']));
      final limited = hospitals.take(10).toList();
      print('📍 Final hospitals count: ${limited.length}');

      setState(() => nearbyHospitals = limited);
    } catch (e) {
      print('❌ Exception in _fetchNearbyHospitals: $e');
      debugPrint('Error fetching hospitals: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSearchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() => _searchSuggestions = []);
      return;
    }
    if (_currentPosition == null) return;

    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?'
            'input=$query'
            '&location=${_currentPosition!.latitude},${_currentPosition!.longitude}'
            '&radius=15000'
            '&key=$_googleApiKey');

    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final predictions = (data['predictions'] as List?) ?? [];
        final filtered = predictions.where((pred) {
          final desc = (pred['description'] ?? '').toString().toLowerCase();
          return _hospitalKeywords.any((kw) => desc.contains(kw));
        }).toList();
        setState(() => _searchSuggestions = filtered);
      }
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
    }
  }

  void _showPrioritySelectionSheet(Map<String, dynamic> hospital) {
    setState(() => _selectedHospital = hospital);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPrioritySelectionBottomSheet(),
    );
  }

  void _listenForAssignedRequest() {
    final database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
    ).ref();

    _assignedRequestSubscription = database
        .child('emergency_requests')
        .orderByChild('ambulanceId')
        .equalTo(widget.ambulanceId)
        .onValue
        .listen((event) {
      if (!mounted || _isNavigatingToRequest) return;
      if (event.snapshot.exists) {
        final requests = event.snapshot.value as Map<dynamic, dynamic>;
        for (var entry in requests.entries) {
          final data = Map<String, dynamic>.from(entry.value);
          if (data['status'] == 'pending') {
            _showAssignedRequestNotification(data, entry.key);
            if (mounted && !_isNavigatingToRequest) {
              _handleAssignedRequest(entry.key, data);
            }
            break;
          }
        }
      }
    });
  }

  Future<void> _showAssignedRequestNotification(Map<String, dynamic> data, String requestId) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'assigned_requests',
      'Assigned Emergency Requests',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    String title = '🚑 New Emergency Assigned';
    String body = 'Destination: ${data['destination'] ?? 'Unknown'}';

    double? destLat, destLng;
    if (data['destCoords'] != null) {
      destLat = (data['destCoords']['lat'] as num?)?.toDouble();
      destLng = (data['destCoords']['lng'] as num?)?.toDouble();
    }

    Map<String, dynamic> payloadData = {
      'requestId': requestId,
      'ambulanceId': widget.ambulanceId,
      'destination': data['destination'] ?? 'Hospital',
      'destLat': destLat ?? 0.0,
      'destLng': destLng ?? 0.0,
      'priority': data['priority'] ?? 3,
      'description': data['description'] ?? '',
    };
    String payload = jsonEncode(payloadData);

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  void _handleAssignedRequest(String requestId, Map<String, dynamic> data) {
    if (!mounted || _isNavigatingToRequest) return;

    double? destLat, destLng;
    if (data['destCoords'] != null) {
      destLat = (data['destCoords']['lat'] as num?)?.toDouble();
      destLng = (data['destCoords']['lng'] as num?)?.toDouble();
    }

    if (destLat == null || destLng == null) {
      print('❌ No destination coordinates in request');
      return;
    }

    EmergencyPriority priority = EmergencyPriority.values.first;
    if (data['priority'] != null) {
      final priorityValue = data['priority'] as int;
      if (priorityValue >= 0 && priorityValue < EmergencyPriority.values.length) {
        priority = EmergencyPriority.values[priorityValue];
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.emergency, color: Colors.red),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '🚨 New Emergency Assigned',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Destination:',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['destination'] ?? 'Unknown Hospital',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (data['description'] != null && data['description'].toString().isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emergency Details:',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(data['description']),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.priority_high, color: Colors.amber.shade800, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Priority: ${data['priorityLabel'] ?? 'MEDIUM'}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('IGNORE'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _acceptRequest(requestId);
              _navigateToRequest(data, destLat!, destLng!, priority, requestId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ACCEPT'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptRequest(String requestId) async {
    try {
      await FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
      ).ref()
          .child('emergency_requests')
          .child(requestId)
          .update({
        'status': 'accepted',
        'accepted_at': ServerValue.timestamp,
      });
      print('✅ Request $requestId accepted');
    } catch (e) {
      print('❌ Failed to accept request: $e');
    }
  }

  Widget _buildPrioritySelectionBottomSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Emergency Priority',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'Destination: ${_selectedHospital!['name']}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ...EmergencyPriority.values.map((priority) {
              final config = PriorityConfig.fromPriority(priority);
              return GestureDetector(
                onTap: () {
                  if (priority == EmergencyPriority.critical) {
                    _showCriticalPriorityVerification(priority);
                  } else {
                    _startNavigationWithPriority(priority);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: config.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: config.color, width: 2),
                  ),
                  child: Row(
                    children: [
                      Icon(config.icon, color: config.color, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              config.label,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: config.color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              config.description,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: config.color, size: 18),
                    ],
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showCriticalPriorityVerification(EmergencyPriority priority) {
    Navigator.pop(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'CRITICAL Priority Verification',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ CRITICAL Priority is for:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Cardiac arrest\n'
                          '• Severe trauma/bleeding\n'
                          '• Unconscious patient\n'
                          '• Respiratory failure\n'
                          '• Stroke symptoms',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Provide justification for CRITICAL priority:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _justificationController,
                maxLines: 3,
                maxLength: 150,
                decoration: InputDecoration(
                  hintText: 'Describe the emergency condition...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Misuse will be logged and reported',
                        style: TextStyle(fontSize: 11, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _justificationController.clear();
              Navigator.pop(context);
              _showPrioritySelectionSheet(_selectedHospital!);
            },
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              final justification = _justificationController.text.trim();
              if (justification.isEmpty || justification.length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a valid justification (min 10 characters)'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _startNavigationWithPriority(priority, justification: justification);
              _justificationController.clear();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('CONFIRM', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _startNavigationWithPriority(EmergencyPriority priority, {String? justification}) {
    if (_selectedHospital == null) return;
    if (priority == EmergencyPriority.critical && justification != null) {
      _logCriticalPriorityUsage(justification);
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RouteNavigationScreen(
          ambulanceId: widget.ambulanceId,
          destination: _selectedHospital!['name'],
          destinationLat: _selectedHospital!['lat'],
          destinationLng: _selectedHospital!['lng'],
          onToggleTheme: widget.onToggleTheme,
          priority: priority,
          justification: justification,
        ),
      ),
    );
  }

  Future<void> _logCriticalPriorityUsage(String justification) async {
    try {
      final logsRef = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
      ).ref().child('critical_priority_logs').push();
      await logsRef.set({
        'ambulanceId': widget.ambulanceId,
        'destination': _selectedHospital!['name'],
        'justification': justification,
        'timestamp': ServerValue.timestamp,
        'location': 'Lat: ${_currentPosition?.latitude}, Lng: ${_currentPosition?.longitude}',
      });
      debugPrint('✅ Critical priority usage logged');
    } catch (e) {
      debugPrint('❌ Failed to log critical priority: $e');
    }
  }

  Widget _buildHospitalCard(Map<String, dynamic> hospital) {
    final String name = hospital['name'] ?? '';
    final String address = hospital['address'] ?? '';
    final double rating = hospital['rating'] ?? 0.0;
    final String distance = hospital['distance_text'] ?? '';
    final bool isOpen = hospital['isOpen'] ?? false;
    final bool isOpenKnown = hospital['isOpeningStatusKnown'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () => _showPrioritySelectionSheet(hospital),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_hospital, color: Colors.red.shade700, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (rating > 0) ...[
                              const Icon(Icons.star, color: Colors.amber, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                rating.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white70
                                      : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            if (isOpenKnown) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isOpen ? Colors.green.shade50 : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isOpen ? 'OPEN' : 'CLOSED',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isOpen ? Colors.green.shade700 : Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                address,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.grey.shade600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.directions_car, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        distance,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(20)),
                    child: const Text(
                      'Select',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _destinationController,
                onChanged: (value) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), () {
                    _fetchSearchSuggestions(value);
                  });
                },
                decoration: InputDecoration(
                  hintText: "Search hospital destination",
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _destinationController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _destinationController.clear();
                      setState(() => _searchSuggestions = []);
                    },
                  )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              if (_searchSuggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchSuggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _searchSuggestions[index];
                      final description = suggestion['description'] ?? '';
                      return ListTile(
                        title: Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () async {
                          _destinationController.text = description;
                          setState(() => _searchSuggestions = []);
                          final placeId = suggestion['place_id'];
                          final detailsUrl = Uri.parse(
                              'https://maps.googleapis.com/maps/api/place/details/json'
                                  '?place_id=$placeId&key=$_googleApiKey');
                          final detailsResp = await http.get(detailsUrl);
                          if (detailsResp.statusCode == 200) {
                            final detailsData = json.decode(detailsResp.body);
                            final loc = detailsData['result']['geometry']['location'];
                            final double lat = (loc['lat'] as num).toDouble();
                            final double lng = (loc['lng'] as num).toDouble();
                            _showPrioritySelectionSheet({
                              'name': description,
                              'lat': lat,
                              'lng': lng,
                              'address': description,
                              'rating': 0.0,
                              'distance_text': 'N/A',
                            });
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'Nearby Hospitals',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh nearby hospitals',
                icon: const Icon(Icons.refresh, color: Colors.red),
                onPressed: _refreshLocationAndHospitals,
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : nearbyHospitals.isEmpty
              ? const Center(
            child: Text(
              'No emergency hospitals found nearby',
              style: TextStyle(color: Colors.grey),
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: nearbyHospitals.length,
            itemBuilder: (context, index) {
              final hospital = nearbyHospitals[index];
              return _buildHospitalCard(hospital);
            },
          ),
        ),
      ],
    );
  }

  Future<void> _checkForExistingRequest() async {
    try {
      final snapshot = await FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
      ).ref()
          .child('emergency_requests')
          .orderByChild('ambulanceId')
          .equalTo(widget.ambulanceId)
          .once();

      if (snapshot.snapshot.exists && mounted) {
        final requests = snapshot.snapshot.value as Map<dynamic, dynamic>;
        for (var entry in requests.entries) {
          final data = Map<String, dynamic>.from(entry.value);
          if (data['status'] == 'pending') {
            _handleAssignedRequest(entry.key, data);
            break;
          }
        }
      }
    } catch (e) {
      print('❌ Error checking for existing requests: $e');
    }
  }

  void _navigateToRequest(
      Map<String, dynamic> data,
      double destLat,
      double destLng,
      EmergencyPriority priority,
      String requestId,
      ) {
    _isNavigatingToRequest = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RouteNavigationScreen(
          ambulanceId: widget.ambulanceId,
          destination: data['destination'] ?? 'Hospital',
          destinationLat: destLat,
          destinationLng: destLng,
          onToggleTheme: widget.onToggleTheme,
          priority: priority,
          justification: data['description'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.local_shipping_outlined, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              widget.ambulanceId,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.wb_sunny : Icons.nights_stay, color: Colors.white),
            onPressed: widget.onToggleTheme,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildDashboardTab(),
            HistoryScreen(
              ambulanceId: widget.ambulanceId,
              showAppBar: false,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _destinationController.dispose();
    _justificationController.dispose();
    _tabController.dispose();
    _assignedRequestSubscription?.cancel();
    super.dispose();
  }
}