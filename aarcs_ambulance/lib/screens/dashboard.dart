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

  bool _isButtonPressed = false;
  bool _isLoading = false;
  Position? _currentPosition;
  List<Map<String, dynamic>> nearbyHospitals = [];
  Timer? _debounce;
  List<dynamic> _searchSuggestions = [];
  late TabController _tabController;

  // Selected hospital for priority selection
  Map<String, dynamic>? _selectedHospital;

  final String _googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Enhanced filtering keywords
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
  }

  Future<void> _refreshLocationAndHospitals() async {
    setState(() {
      _isLoading = true;
    });

    await _determinePositionWithFallback();
    await _fetchNearbyHospitals();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _determinePositionWithFallback() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Location permissions are permanently denied')),
        );
        return;
      }

      try {
        final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        _currentPosition = pos;
      } catch (e) {
        final last = await Geolocator.getLastKnownPosition();
        _currentPosition = last;
        debugPrint('Current position failed, using lastKnown: $e');
      }
    } catch (e) {
      debugPrint('Error determining position: $e');
    }
  }

  bool _isValidHospital(String name, List<String> types) {
    final String nameLower = name.toLowerCase();

    for (String excludeKeyword in _excludeKeywords) {
      if (nameLower.contains(excludeKeyword.toLowerCase())) {
        return false;
      }
    }

    bool nameMatch =
    _allowedNameKeywords.any((kw) => nameLower.contains(kw.toLowerCase()));

    bool typeMatch = types.any((type) =>
    type.contains('hospital') ||
        type.contains('health') ||
        type.contains('establishment'));

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
    if (currentOpeningHours != null &&
        currentOpeningHours.containsKey('open_now')) {
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

    return {
      'isOpen': false,
      'isKnown': false,
    };
  }

  Future<void> _fetchNearbyHospitals() async {
    nearbyHospitals = [];
    if (_currentPosition == null) {
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

    try {
      setState(() => _isLoading = true);
      final resp = await http.get(Uri.parse(placesUrl));
      if (resp.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Failed to fetch hospitals. Try again later.")),
        );
        return;
      }

      final data = json.decode(resp.body);
      final results = (data['results'] as List?) ?? [];
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

        if (!_isValidHospital(name, types)) {
          continue;
        }

        final double distanceMeters = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          lat,
          lng,
        );

        Map<String, dynamic> openingStatus = {
          'isOpen': false,
          'isKnown': false,
        };

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
                  ? Map<String, dynamic>.from(
                  placeDetails['current_opening_hours'])
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
          'distance_text':
          (distanceMeters / 1000).toStringAsFixed(2) + ' km',
          'isOpen': openingStatus['isOpen'],
          'isOpeningStatusKnown': openingStatus['isKnown'],
        });
      }

      if (hospitals.isEmpty) {
        setState(() {
          nearbyHospitals = [];
        });
        return;
      }

      hospitals.sort(
              (a, b) => (a['distance_m'] as double).compareTo(b['distance_m']));
      final limited = hospitals.take(10).toList();
      setState(() {
        nearbyHospitals = limited;
      });
    } catch (e) {
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
          final desc =
          (pred['description'] ?? '').toString().toLowerCase();
          return _hospitalKeywords.any((kw) => desc.contains(kw));
        }).toList();

        setState(() => _searchSuggestions = filtered);
      }
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
    }
  }

  // ✅ NEW: Show priority selection bottom sheet
  void _showPrioritySelectionSheet(Map<String, dynamic> hospital) {
    setState(() {
      _selectedHospital = hospital;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPrioritySelectionBottomSheet(),
    );
  }

  // ✅ NEW: Priority selection bottom sheet UI
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
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Destination: ${_selectedHospital!['name']}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ...EmergencyPriority.values.map((priority) {
              final config = PriorityConfig.fromPriority(priority);
              return GestureDetector(
                onTap: () {
                  // ✅ ANTI-MISUSE: Show verification for CRITICAL priority
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
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: config.color,
                        size: 18,
                      ),
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

  // ✅ NEW: Critical priority verification with justification
  void _showCriticalPriorityVerification(EmergencyPriority priority) {
    Navigator.pop(context); // Close priority sheet

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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Cardiac arrest\n'
                          '• Severe trauma/bleeding\n'
                          '• Unconscious patient\n'
                          '• Respiratory failure\n'
                          '• Stroke symptoms',
                      style:
                      TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Provide justification for CRITICAL priority:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _justificationController,
                maxLines: 3,
                maxLength: 150,
                decoration: InputDecoration(
                  hintText: 'Describe the emergency condition...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Misuse will be logged and reported',
                        style:
                        TextStyle(fontSize: 11, color: Colors.orange),
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
              // Show priority sheet again
              _showPrioritySelectionSheet(_selectedHospital!);
            },
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              final justification =
              _justificationController.text.trim();
              if (justification.isEmpty || justification.length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Please provide a valid justification (min 10 characters)'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              _startNavigationWithPriority(priority,
                  justification: justification);
              _justificationController.clear();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('CONFIRM',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Start navigation with selected priority
  void _startNavigationWithPriority(EmergencyPriority priority,
      {String? justification}) {
    if (_selectedHospital == null) return;

    // Log critical priority usage
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
          justification: justification, // ✅ PASS TO ROUTE SCREEN
        ),
      ),
    );
  }

  // ✅ NEW: Log critical priority usage to Firebase for monitoring
  Future<void> _logCriticalPriorityUsage(String justification) async {
    try {
      final logsRef = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
        'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
      ).ref().child('critical_priority_logs').push();

      await logsRef.set({
        'ambulanceId': widget.ambulanceId,
        'destination': _selectedHospital!['name'],
        'justification': justification,
        'timestamp': ServerValue.timestamp,
        'location':
        'Lat: ${_currentPosition?.latitude}, Lng: ${_currentPosition?.longitude}',
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
        onTap: () {
          _showPrioritySelectionSheet(hospital);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.local_hospital,
                      color: Colors.red.shade700,
                      size: 20,
                    ),
                  ),
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
                            color: Theme.of(context).brightness ==
                                Brightness.dark
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
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                rating.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).brightness ==
                                      Brightness.dark
                                      ? Colors.white70
                                      : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            if (isOpenKnown) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isOpen
                                      ? Colors.green.shade50
                                      : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isOpen ? 'OPEN' : 'CLOSED',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isOpen
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
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
                      Icon(Icons.directions_car,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        distance,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).brightness ==
                              Brightness.dark
                              ? Colors.white
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Select',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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
        // Search bar at top
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _destinationController,
                onChanged: (value) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce =
                      Timer(const Duration(milliseconds: 500), () {
                        _fetchSearchSuggestions(value);
                      });
                },
                decoration: InputDecoration(
                  hintText: "Search hospital destination",
                  prefixIcon:
                  const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _destinationController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _destinationController.clear();
                      setState(() => _searchSuggestions = []);
                    },
                  )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              // Search suggestions dropdown
              if (_searchSuggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4)
                    ],
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
                            final detailsData =
                            json.decode(detailsResp.body);
                            final loc = detailsData['result']['geometry']
                            ['location'];
                            final double lat =
                            (loc['lat'] as num).toDouble();
                            final double lng =
                            (loc['lng'] as num).toDouble();
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
        // Nearby Hospitals header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'Nearby Hospitals',
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh nearby hospitals',
                icon:
                const Icon(Icons.refresh, color: Colors.red),
                onPressed: _refreshLocationAndHospitals,
              ),
            ],
          ),
        ),
        // Hospital list
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
            padding:
            const EdgeInsets.symmetric(horizontal: 16),
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

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.local_shipping_outlined,
                color: Colors.white),
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
            icon: Icon(
                isDark ? Icons.wb_sunny : Icons.nights_stay,
                color: Colors.white),
            onPressed: widget.onToggleTheme,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 16),
          tabs: const [
            Tab(
              icon: Icon(Icons.dashboard),
              text: 'Dashboard',
            ),
            Tab(
              icon: Icon(Icons.history),
              text: 'History',
            ),
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
    super.dispose();
  }
}
