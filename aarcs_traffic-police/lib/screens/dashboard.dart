// lib/screens/dashboard.dart (Traffic Police)

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'emergency_response_screen.dart';
import 'history_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/priority_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// Firebase Police Service for real-time data
class FirebasePoliceService {
  static final DatabaseReference _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
  ).ref();

  static Stream<DatabaseEvent> listenToEmergencyRequests() {
    return _database
        .child('emergency_requests')
        .orderByChild('timestamp')
        .limitToLast(5)
        .onValue;
  }

  static Future<void> acceptRequest(String requestId) async {
    await _database.child('emergency_requests').child(requestId).update({
      'status': 'accepted',
      'acceptedAt': ServerValue.timestamp,
    });
  }
}

class AARCSTrafficPoliceDashboard extends StatefulWidget {
  @override
  _AARCSTrafficPoliceDashboardState createState() => _AARCSTrafficPoliceDashboardState();
}

class _AARCSTrafficPoliceDashboardState extends State<AARCSTrafficPoliceDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isOnDuty = true;
  bool isConnected = true;
  int _selectedTabIndex = 0;

  // Emergency request state
  bool hasEmergencyAlert = false;
  bool hasActiveEmergencyRequest = false;
  Map<String, dynamic>? currentEmergencyRequest;
  String? currentRequestId;

  // Firebase subscription
  StreamSubscription<DatabaseEvent>? _requestSubscription;

  // Location tracking variables
  String currentLocationText = "Fetching location...";
  String currentLandmark = "";
  Position? currentPosition;
  StreamSubscription<Position>? _locationSubscription;
  bool isLoadingLocation = true;

  // Google API Key
  final String _googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
    _listenToEmergencyRequests();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _requestSubscription?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  // Start real-time location tracking
  Future<void> _startLocationTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          currentLocationText = "Location services disabled";
          isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            currentLocationText = "Location permission denied";
            isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          currentLocationText = "Location permission permanently denied";
          isLoadingLocation = false;
        });
        return;
      }

      Position initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _updateLocationText(initialPosition);

      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        _updateLocationText(position);
      });
    } catch (e) {
      print("Error getting location: $e");
      setState(() {
        currentLocationText = "Location unavailable";
        isLoadingLocation = false;
      });
    }
  }

  // ✅ UPDATED: Get nearest landmark using Google Places API
  Future<void> _updateLocationText(Position position) async {
    try {
      setState(() {
        currentPosition = position;
      });

      // Get nearest landmark using Google Places Nearby Search
      final nearbyLandmark = await _getNearestLandmark(position.latitude, position.longitude);

      if (nearbyLandmark != null) {
        setState(() {
          currentLocationText = nearbyLandmark['name'];
          currentLandmark = nearbyLandmark['vicinity'];
          isLoadingLocation = false;
        });
      } else {
        // Fallback to reverse geocoding
        await _fallbackReverseGeocode(position);
      }
    } catch (e) {
      print("Error updating location: $e");
      await _fallbackReverseGeocode(position);
    }
  }

  // ✅ NEW: Get nearest landmark using Google Places API
  Future<Map<String, dynamic>?> _getNearestLandmark(double lat, double lng) async {
    try {
      // Search for nearby prominent places (landmarks, establishments, points of interest)
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?'
              'location=$lat,$lng&'
              'radius=100&'
              'type=point_of_interest|establishment|transit_station|bus_station|shopping_mall|store|restaurant|cafe|bank|atm|hospital|school|university|park|stadium|museum&'
              'rankby=distance&'
              'key=$_googleApiKey'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'] != null && (data['results'] as List).isNotEmpty) {
          final results = data['results'] as List;

          // Get the closest landmark
          for (var place in results) {
            final name = place['name'];
            final vicinity = place['vicinity'] ?? '';

            // Skip generic or unclear names
            if (name != null &&
                !name.toString().toLowerCase().contains('unnamed') &&
                name.toString().length > 2) {
              return {
                'name': 'Near $name',
                'vicinity': vicinity,
              };
            }
          }
        }
      }
    } catch (e) {
      print("Error getting nearest landmark: $e");
    }
    return null;
  }

  // ✅ UPDATED: Fallback to basic reverse geocoding
  Future<void> _fallbackReverseGeocode(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = '';

        if (place.street != null && place.street!.isNotEmpty) {
          address = place.street!;
        } else if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          address = place.subLocality!;
        } else if (place.locality != null && place.locality!.isNotEmpty) {
          address = place.locality!;
        } else {
          address = "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
        }

        List<String> landmarkParts = [];

        if (place.subLocality != null && place.subLocality!.isNotEmpty && place.subLocality != address) {
          landmarkParts.add(place.subLocality!);
        }

        if (place.locality != null && place.locality!.isNotEmpty && place.locality != address) {
          landmarkParts.add(place.locality!);
        }

        String landmark = landmarkParts.join(', ');

        setState(() {
          currentLocationText = address;
          currentLandmark = landmark;
          isLoadingLocation = false;
        });
      } else {
        setState(() {
          currentLocationText = "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
          currentLandmark = "Unknown Area";
          isLoadingLocation = false;
        });
      }
    } catch (e) {
      print("Error reverse geocoding: $e");
      setState(() {
        currentLocationText = "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
        currentLandmark = "Location service unavailable";
        isLoadingLocation = false;
      });
    }
  }

  // ✅ UPDATED: Convert lat/lng to landmark for emergency requests
  Future<String> _convertCoordsToLandmark(String coordString) async {
    try {
      // Extract lat/lng from string like "Lat: 12.9716, Lng: 77.5946"
      final regex = RegExp(r'Lat:\s*([-\d.]+),\s*Lng:\s*([-\d.]+)');
      final match = regex.firstMatch(coordString);

      if (match != null) {
        final lat = double.parse(match.group(1)!);
        final lng = double.parse(match.group(2)!);

        // Get nearest landmark
        final landmark = await _getNearestLandmark(lat, lng);
        if (landmark != null) {
          return landmark['name'];
        }

        // Fallback to reverse geocoding
        List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          if (place.street != null && place.street!.isNotEmpty) {
            return place.street!;
          } else if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            return place.subLocality!;
          } else if (place.locality != null && place.locality!.isNotEmpty) {
            return place.locality!;
          }
        }
      }
    } catch (e) {
      print("Error converting coords to landmark: $e");
    }
    return coordString; // Return original if conversion fails
  }

  // ✅ UPDATED: Filter to show only highest priority ambulance with landmark conversion
  void _listenToEmergencyRequests() {
    print("Traffic Police: Starting to listen for emergency requests...");

    _requestSubscription = FirebasePoliceService.listenToEmergencyRequests().listen((DatabaseEvent event) {
      print("Traffic Police: Firebase event received!");
      print("Data exists: ${event.snapshot.exists}");
      print("Event type: ${event.type}");

      if (event.snapshot.exists && mounted) {
        print("Raw data: ${event.snapshot.value}");
        final requests = Map<String, dynamic>.from(event.snapshot.value as Map<dynamic, dynamic>);
        print("Number of requests: ${requests.length}");

        final pendingRequests = <String, Map<String, dynamic>>{};
        requests.forEach((key, value) {
          final requestData = Map<String, dynamic>.from(value);
          final status = requestData['status']?.toString() ?? '';
          print("Request $key - Status: $status");
          if (status == 'pending') {
            pendingRequests[key.toString()] = requestData;
          }
        });

        print("Filtered pending requests: ${pendingRequests.length}");

        if (pendingRequests.isNotEmpty) {
          var sortedEntries = pendingRequests.entries.toList()
            ..sort((a, b) {
              final priorityA = a.value['priority'] ?? 3;
              final priorityB = b.value['priority'] ?? 3;

              if (priorityA != priorityB) {
                return (priorityA as num).compareTo(priorityB as num);
              }

              final timestampA = a.value['timestamp'] ?? 0;
              final timestampB = b.value['timestamp'] ?? 0;
              return (timestampB as num).compareTo(timestampA as num);
            });

          final highestPriorityEntry = sortedEntries.first;
          final requestId = highestPriorityEntry.key;
          final requestData = highestPriorityEntry.value;

          if (currentRequestId == requestId && hasActiveEmergencyRequest) {
            print("Request $requestId already being displayed, skipping...");
            return;
          }

          print("Processing HIGHEST PRIORITY request: $requestId");
          print("Priority: ${requestData['priority']} - ${requestData['priorityLabel']}");
          print("Destination: ${requestData['destination']}");

          // ✅ Convert currentLocation coordinates to landmark
          String currentLoc = requestData['currentLocation'] ?? 'Unknown';
          _convertCoordsToLandmark(currentLoc).then((landmark) {
            setState(() {
              hasEmergencyAlert = true;
              hasActiveEmergencyRequest = true;
              currentRequestId = requestId;

              final sourceCoords = requestData['sourceCoords'] is Map
                  ? Map<String, dynamic>.from(requestData['sourceCoords'])
                  : null;
              final destCoords = requestData['destCoords'] is Map
                  ? Map<String, dynamic>.from(requestData['destCoords'])
                  : null;

              currentEmergencyRequest = {
                'ambulanceId': requestData['ambulanceId'] ?? 'Unknown',
                'currentLocation': landmark, // ✅ Use converted landmark
                'destination': requestData['destination'] ?? 'Unknown',
                'eta': requestData['eta'] ?? 'Calculating...',
                'distance': requestData['distance'] ?? 'N/A',
                'priority': requestData['priority'] ?? 3,
                'priorityLabel': requestData['priorityLabel'] ?? 'LOW',
                'sourceCoords': sourceCoords,
                'destCoords': destCoords,
              };
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${requestData['priorityLabel']} PRIORITY: ${requestData['ambulanceId']} → ${requestData['destination']}',
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
              ),
            );
          });
        } else {
          print("No pending requests found, clearing alerts...");
          if (hasEmergencyAlert || hasActiveEmergencyRequest) {
            setState(() {
              hasEmergencyAlert = false;
              hasActiveEmergencyRequest = false;
              currentEmergencyRequest = null;
              currentRequestId = null;
            });
          }
        }
      } else {
        print("No emergency requests data exists");
        if (hasEmergencyAlert || hasActiveEmergencyRequest) {
          setState(() {
            hasEmergencyAlert = false;
            hasActiveEmergencyRequest = false;
            currentEmergencyRequest = null;
            currentRequestId = null;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (hasEmergencyAlert) _buildEmergencyAlert(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(),
                _buildHistoryTab(),
                _buildProfileTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1976D2),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        color: Colors.white,
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AARCS Traffic Police',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isConnected ? 'Connected' : 'Disconnected',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 8),
          child: Text(
            '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Dashboard'),
          Tab(text: 'History'),
          Tab(text: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildEmergencyAlert() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.red,
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'EMERGENCY ALERT: ambulance clearance request in your zone',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            color: Colors.white,
            iconSize: 20,
            onPressed: () {
              setState(() {
                hasEmergencyAlert = false;
              });
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBadgeCard(),
          const SizedBox(height: 20),
          hasActiveEmergencyRequest
              ? _buildEmergencyRequestCard()
              : _buildActiveRequestsCard(),
        ],
      ),
    );
  }

  Widget _buildBadgeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.badge,
              color: Color(0xFF1976D2),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Badge: TP-2024-156',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    if (isLoadingLocation)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                        ),
                      ),
                    if (isLoadingLocation) const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        currentLocationText,
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (currentLandmark.isNotEmpty && !isLoadingLocation)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 18),
                    child: Text(
                      currentLandmark,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              Switch(
                value: isOnDuty,
                onChanged: (value) {
                  setState(() {
                    isOnDuty = value;
                  });
                },
                activeColor: const Color(0xFF4CAF50),
              ),
              Text(
                'ON DUTY',
                style: TextStyle(
                  fontSize: 10,
                  color: isOnDuty ? const Color(0xFF4CAF50) : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyRequestCard() {
    final priority = EmergencyPriority.values[currentEmergencyRequest!['priority'] ?? 3];
    final priorityConfig = PriorityConfig.fromPriority(priority);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: priorityConfig.color, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: priorityConfig.backgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: priorityConfig.color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    priorityConfig.icon,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'EMERGENCY REQUEST',
                  style: TextStyle(
                    color: priorityConfig.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityConfig.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    priorityConfig.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Ambulance ID: ${currentEmergencyRequest!['ambulanceId']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailRow('Current', currentEmergencyRequest!['currentLocation']),
                const SizedBox(height: 12),
                _buildDetailRow('Destination', currentEmergencyRequest!['destination'] ?? 'Unknown'),
                const SizedBox(height: 12),
                _buildDetailRow('ETA', currentEmergencyRequest!['eta'] ?? '--'),
                const SizedBox(height: 12),
                _buildDetailRow('Distance', currentEmergencyRequest!['distance'] ?? '--'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _navigateToEmergencyResponse,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: priorityConfig.color,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'CLEAR ROUTE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveRequestsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield,
              size: 48,
              color: Color(0xFF1976D2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Active Requests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All clear in your zone',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Last updated: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return const HistoryScreen(
      ambulanceId: null,
      showAppBar: false,
    );
  }

  Widget _buildProfileTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: Color(0xFF1976D2),
            child: Icon(
              Icons.person,
              size: 40,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Inspector Raggul J',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Badge: TP-2024-156',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToEmergencyResponse() async {
    if (currentEmergencyRequest != null && currentRequestId != null) {
      try {
        print("Navigating to Emergency Response Screen");
        print("Request ID: $currentRequestId");
        print("Emergency Request data: $currentEmergencyRequest");

        final requestDataCopy = Map<String, dynamic>.from(currentEmergencyRequest!);
        final requestIdCopy = currentRequestId!;

        setState(() {
          hasActiveEmergencyRequest = false;
          hasEmergencyAlert = false;
          currentEmergencyRequest = null;
          currentRequestId = null;
        });

        await FirebasePoliceService.acceptRequest(requestIdCopy);
        print("Request accepted in Firebase");

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmergencyResponseScreen(
                emergencyRequest: requestDataCopy,
              ),
            ),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Route clearance accepted'),
              backgroundColor: Color(0xFF4CAF50),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e, stackTrace) {
        print("Error navigating to emergency response: $e");
        print("Stack trace: $stackTrace");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to process request: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      print("No emergency request data available");
      print("currentEmergencyRequest: $currentEmergencyRequest");
      print("currentRequestId: $currentRequestId");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No emergency request data available'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}
