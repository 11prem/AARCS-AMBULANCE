// lib/screens/route_navigation.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';

import '../models/priority_model.dart';

// Firebase Service for Ambulance
class FirebaseAmbulanceService {
  static final DatabaseReference _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
  ).ref();

  static Future<String?> sendRouteRequest({
    required String ambulanceId,
    required String destinationName,
    required double currentLat,
    required double currentLng,
    required double destLat,
    required double destLng,
    String? eta,
    String? distance,
    required EmergencyPriority priority,
    required String apiKey,
    String? justification,
  }) async {
    try {
      print('📝 Preparing Firebase write with priority: ${priority.index}...');

      String currentLocationLandmark = await _getLocationLandmark(currentLat, currentLng, apiKey);

      final requestRef = _database.child('emergency_requests').push();
      final requestId = requestRef.key;

      print('📝 Generated Request ID: $requestId');

      final requestData = {
        'ambulanceId': ambulanceId,
        'destination': destinationName,
        'currentLocation': currentLocationLandmark,
        'status': 'pending',
        'timestamp': ServerValue.timestamp,
        'eta': eta ?? 'N/A',
        'distance': distance ?? 'N/A',
        'priority': priority.index,
        'priorityLabel': PriorityConfig.fromPriority(priority).label,
        'description': justification ?? '',
        'sourceCoords': {
          'lat': currentLat,
          'lng': currentLng,
        },
        'destCoords': {
          'lat': destLat,
          'lng': destLng,
        },
      };

      await requestRef.set(requestData);

      print('✅ Firebase write SUCCESS!');
      return requestId;
    } catch (e) {
      print('❌ Firebase write FAILED: $e');
      return null;
    }
  }

  // ✅ NEW: Send traffic clearance alert
  static Future<void> sendTrafficClearanceAlert({
    required String ambulanceId,
    required String destination,
    required String eta,
    required String distance,
    required int priority,
    required String priorityLabel,
    required String currentLocation,
    required String? requestId,
  }) async {
    try {
      final alertRef = _database.child('traffic_clearance_alerts').push();
      final alertId = alertRef.key;

      final alertData = {
        'alertId': alertId,
        'ambulanceId': ambulanceId,
        'destination': destination,
        'eta': eta,
        'distance': distance,
        'priority': priority,
        'priorityLabel': priorityLabel,
        'currentLocation': currentLocation,
        'requestId': requestId,
        'timestamp': ServerValue.timestamp,
        'status': 'active',
        'acknowledged': false,
        'acknowledgedBy': null,
        'acknowledgedAt': null,
      };

      await alertRef.set(alertData);

      print('✅ Traffic clearance alert sent to Firebase: $alertId');

      if (requestId != null) {
        await _database.child('emergency_requests').child(requestId).update({
          'trafficClearanceRequested': true,
          'trafficClearanceTime': ServerValue.timestamp,
          'latestTrafficAlertId': alertId,
        });
      }
    } catch (e) {
      print('❌ Error sending traffic clearance alert: $e');
    }
  }

  static Future<String> _getLocationLandmark(double lat, double lng, String apiKey) async {
    try {
      final placesUrl = Uri.parse('https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=100&type=point_of_interest|establishment|transit_station|bus_station|hospital|school|shopping_mall|store|restaurant|cafe|bank|atm|park|stadium|museum&key=$apiKey');

      final placesResponse = await http.get(placesUrl);
      if (placesResponse.statusCode == 200) {
        final placesData = json.decode(placesResponse.body);
        if (placesData['status'] == 'OK' && placesData['results'] != null && (placesData['results'] as List).isNotEmpty) {
          final results = placesData['results'] as List;
          for (var place in results) {
            final name = place['name'];
            if (name != null && !name.toString().toLowerCase().contains('unnamed') && name.toString().length > 2) {
              return 'Near $name';
            }
          }
        }
      }

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
    } catch (e) {
      print('❌ Error getting landmark: $e');
    }

    return 'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}';
  }
}

class RouteProgressHelper {
  static const double _earthRadius = 6371000;

  static double distanceHaversine(LatLng point1, LatLng point2) {
    double lat1Rad = point1.latitude * (math.pi / 180);
    double lat2Rad = point2.latitude * (math.pi / 180);
    double deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180);
    double deltaLngRad = (point2.longitude - point1.longitude) * (math.pi / 180);

    double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return _earthRadius * c;
  }

  static int findNearestPointOnRoute(LatLng currentPosition, List<LatLng> routePoints) {
    if (routePoints.isEmpty) return 0;

    double minDistance = double.infinity;
    int nearestIndex = 0;

    for (int i = 0; i < routePoints.length; i++) {
      double distance = distanceHaversine(currentPosition, routePoints[i]);
      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }

    return nearestIndex;
  }
}

class RouteNavigationScreen extends StatefulWidget {
  final String ambulanceId;
  final String destination;
  final double? destinationLat;
  final double? destinationLng;
  final VoidCallback onToggleTheme;
  final EmergencyPriority priority;
  final String? justification;

  const RouteNavigationScreen({
    super.key,
    required this.ambulanceId,
    required this.destination,
    required this.destinationLat,
    required this.destinationLng,
    required this.onToggleTheme,
    required this.priority,
    this.justification,
  });

  @override
  State createState() => _RouteNavigationScreenState();
}

class _RouteNavigationScreenState extends State<RouteNavigationScreen> {
  bool _hasCompletedTrip = false;
  String? _activeRequestId;
  bool _isCompletingTrip = false;
  bool _hasStartedNavigation = false;

  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  String _eta = "--";
  String _distance = "--";
  double _currentSpeed = 0.0;
  // ignore: unused_field
  bool _isLocationActive = false;
  bool _isTrafficClearing = false;
  bool _isLoading = true;
  String? _errorMessage;
  BitmapDescriptor? _ambulanceIcon;
  // ignore: unused_field
  double _currentZoom = 18.5;

  bool _isNavigating = false;
  List<dynamic> _routeSteps = [];
  int _currentStepIndex = 0;
  String _currentInstruction = "";
  String _nextInstruction = "";
  // ignore: unused_field
  double _distanceToNextTurn = 0.0;
  double _currentBearing = 0.0;

  List<LatLng> _routePoints = [];
  int _currentRoutePointIndex = 0;

  Timer? _routeUpdateTimer;
  Timer? _instructionDismissTimer;
  bool _showInstructionCard = true;

  Timer? _acknowledgmentCheckTimer;
  bool _isWaitingForPolice = false;
  String? _lastAlertId;

  final String _apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkerIcon();
    _initializeNavigation();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController?.dispose();
    _routeUpdateTimer?.cancel();
    _instructionDismissTimer?.cancel();
    _acknowledgmentCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCustomMarkerIcon() async {
    try {
      _ambulanceIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/icons/amb.png',
      );
    } catch (e) {
      debugPrint('Failed to load custom marker: $e');
    }
  }

  Future<void> _initializeNavigation() async {
    setState(() => _isLoading = true);
    await _determinePosition();
    await _getDirectionsAndRoute();
    _fitMapBounds();
    setState(() => _isLoading = false);
  }

  void _fitMapBounds() {
    if (_mapController == null || _routePoints.isEmpty) return;

    double minLat = _routePoints.first.latitude;
    double maxLat = _routePoints.first.latitude;
    double minLng = _routePoints.first.longitude;
    double maxLng = _routePoints.first.longitude;

    for (var point in _routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  Future<void> _determinePosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        setState(() {
          _errorMessage = 'Location services disabled. Please enable.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Location permission denied';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permissions are permanently denied';
        });
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      debugPrint('Current position: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
    } catch (e) {
      debugPrint('Error getting position: $e');
      setState(() {
        _errorMessage = 'Failed to get location: $e';
      });
    }
  }

  void _onStartNavigation() async {
    setState(() {
      _hasStartedNavigation = true;
    });

    if (_currentPosition == null || widget.destinationLat == null || widget.destinationLng == null) {
      return;
    }

    final requestId = await FirebaseAmbulanceService.sendRouteRequest(
      ambulanceId: widget.ambulanceId,
      destinationName: widget.destination,
      currentLat: _currentPosition!.latitude,
      currentLng: _currentPosition!.longitude,
      destLat: widget.destinationLat!,
      destLng: widget.destinationLng!,
      eta: _eta,
      distance: _distance,
      priority: widget.priority,
      apiKey: _apiKey,
      justification: widget.justification,
    );

    if (requestId != null) {
      _activeRequestId = requestId;
      _startLocationTracking();
      _startNavigationMode();
    }

    if (_activeRequestId == null && widget.ambulanceId != null) {
      try {
        final snapshot = await FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
        ).ref()
            .child('emergency_requests')
            .orderByChild('ambulanceId')
            .equalTo(widget.ambulanceId)
            .limitToLast(1)
            .once();

        if (snapshot.snapshot.exists) {
          final requests = snapshot.snapshot.value as Map;
          final existingRequestId = requests.keys.first;
          final existingData = requests[existingRequestId] as Map;

          if (existingData['status'] == 'pending') {
            await FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
            ).ref()
                .child('emergency_requests')
                .child(existingRequestId)
                .update({
              'status': 'accepted',
              'accepted_at': ServerValue.timestamp,
              'eta': _eta,
              'distance': _distance,
            });

            _activeRequestId = existingRequestId;
            print('✅ Updated existing request: $existingRequestId');
          }
        }
      } catch (e) {
        print('❌ Error updating existing request: $e');
      }
    }
  }

  Future<void> _getDirectionsAndRoute() async {
    if (_currentPosition == null || widget.destinationLat == null || widget.destinationLng == null) {
      print('❌ Missing position or destination for directions');
      return;
    }

    final url = 'https://maps.googleapis.com/maps/api/directions/json?origin=${_currentPosition!.latitude},${_currentPosition!.longitude}&destination=${widget.destinationLat},${widget.destinationLng}&mode=driving&key=$_apiKey';

    print('📍 Directions URL: $url');

    try {
      final response = await http.get(Uri.parse(url));
      print('📡 Directions API status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📍 Directions API response status: ${data['status']}');

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          print('✅ Route found!');
          print('   Duration: ${leg['duration']['text']}');
          print('   Distance: ${leg['distance']['text']}');

          setState(() {
            _eta = leg['duration']['text'];
            _distance = leg['distance']['text'];
            _routeSteps = List<dynamic>.from(leg['steps']);
          });

          final encodedPolyline = route['overview_polyline']['points'];
          _routePoints = _decodePolyline(encodedPolyline);
          print('📊 Route points decoded: ${_routePoints.length} points');

          _updatePolylines();
          _updateMarkers();

          if (_routeSteps.isNotEmpty) {
            setState(() {
              _currentInstruction = _cleanHtmlTags(_routeSteps[0]['html_instructions']);
              if (_routeSteps.length > 1) {
                _nextInstruction = _cleanHtmlTags(_routeSteps[1]['html_instructions']);
              }
            });
            print('🗺️ First instruction: $_currentInstruction');
          }
        } else {
          print('❌ Directions API error: ${data['status']}');
          if (data['status'] == 'REQUEST_DENIED') {
            print('   This usually means the API key is invalid or restricted');
            print('   Check that:');
            print('   1. API key is correct in .env file');
            print('   2. Directions API is enabled in Google Cloud Console');
            print('   3. API key has no restrictions or allows your app');
          } else if (data['status'] == 'ZERO_RESULTS') {
            print('   No route found between these points');
          }
        }
      } else {
        print('❌ Directions API HTTP error: ${response.statusCode}');
        print('   Response body: ${response.body}');
      }
    } catch (e) {
      print('❌ Exception fetching directions: $e');
      debugPrint('Error fetching directions: $e');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  String _cleanHtmlTags(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '');
  }

  void _startLocationTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      if (!mounted) return;

      final oldPosition = _currentPosition;
      _currentPosition = position;

      if (oldPosition != null) {
        _currentBearing = Geolocator.bearingBetween(
          oldPosition.latitude,
          oldPosition.longitude,
          position.latitude,
          position.longitude,
        );

        final double distanceTraveled = Geolocator.distanceBetween(
          oldPosition.latitude,
          oldPosition.longitude,
          position.latitude,
          position.longitude,
        );

        final num timeDiff = (position.timestamp?.millisecondsSinceEpoch ?? 0) -
            (oldPosition.timestamp?.millisecondsSinceEpoch ?? 0);
        if (timeDiff > 0) {
          _currentSpeed = (distanceTraveled / (timeDiff / 1000)) * 3.6;
        }
      }

      setState(() {
        _isLocationActive = true;
      });

      _updateMarkers();
      _sendLocationToFirebase();

      if (_isNavigating) {
        _updateRouteProgress();
        _updateNavigationCamera();
        _checkIfReachedDestination();
      }
    });
  }

  void _checkIfReachedDestination() {
    if (_currentPosition == null || widget.destinationLat == null || widget.destinationLng == null) {
      return;
    }

    final distanceToDestination = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      widget.destinationLat!,
      widget.destinationLng!,
    );

    if (distanceToDestination < 50 && !_hasCompletedTrip) {
      _hasCompletedTrip = true;
      _showArrivalDialog();
    }
  }

  void _showArrivalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Arrived at Destination',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: const Text(
            'You have reached your destination. Would you like to complete this trip?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('NOT YET'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _completeTrip();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text(
                'COMPLETE TRIP',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _completeTrip() async {
    if (_isCompletingTrip) return;

    setState(() {
      _isCompletingTrip = true;
    });

    try {
      print('🏁 Manually completing trip...');

      final requestQuery = await FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
      )
          .ref()
          .child('emergency_requests')
          .orderByChild('ambulanceId')
          .equalTo(widget.ambulanceId)
          .limitToLast(1)
          .once();

      if (requestQuery.snapshot.value != null) {
        final requests = requestQuery.snapshot.value as Map;
        final requestId = requests.keys.first;
        final requestData = requests[requestId];
        final currentStatus = requestData['status'];

        print('🔍 Found request: $requestId with status: $currentStatus');

        if (currentStatus == 'pending' || currentStatus == 'accepted') {
          await FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
          )
              .ref()
              .child('emergency_requests')
              .child(requestId)
              .update({
            'status': 'completed',
            'completed_at': ServerValue.timestamp,
          });

          print('✅ Trip marked as completed: $requestId');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(child: Text('✅ Trip completed successfully!')),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );

            await Future.delayed(const Duration(milliseconds: 500));

            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 28),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Trip Completed',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                content: const Text(
                  'You have successfully completed this trip. Check the History tab to see your completed trips.',
                  style: TextStyle(fontSize: 14),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'VIEW HISTORY',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }
        } else if (currentStatus == 'completed') {
          print('ℹ️ Trip already completed');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ℹ️ This trip has already been completed'), backgroundColor: Colors.blue),
            );
            await Future.delayed(const Duration(seconds: 1));
            Navigator.of(context).pop();
          }
        } else {
          throw Exception('Cannot complete: Trip is $currentStatus');
        }
      } else {
        print('❌ No active request found for ambulance: ${widget.ambulanceId}');
        throw Exception('No active trip found. Please start a trip first.');
      }
    } catch (e) {
      print('❌ Failed to complete trip: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCompletingTrip = false;
        });
      }
    }
  }

  Future<void> _sendLocationToFirebase() async {
    if (_currentPosition == null || !_hasStartedNavigation) return;

    try {
      final requestQuery = await FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
      )
          .ref()
          .child('emergency_requests')
          .orderByChild('ambulanceId')
          .equalTo(widget.ambulanceId)
          .limitToLast(1)
          .once();

      if (requestQuery.snapshot.value != null) {
        final requests = requestQuery.snapshot.value as Map;
        final requestId = requests.keys.first;
        _activeRequestId = requestId;

        await FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
        )
            .ref()
            .child('emergency_requests')
            .child(requestId)
            .update({
          'liveLocation': {
            'lat': _currentPosition!.latitude,
            'lng': _currentPosition!.longitude,
            'bearing': _currentBearing,
            'speed': _currentSpeed,
            'timestamp': ServerValue.timestamp,
          },
          'eta': _eta,
          'distance': _distance,
          'currentSpeed': _currentSpeed,
        });

        print('📡 Location sent to Firebase: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      }
    } catch (e) {
      print('❌ Failed to send location to Firebase: $e');
    }
  }

  void _updateRouteProgress() {
    if (_routePoints.isEmpty || _currentPosition == null) return;

    LatLng currentLatLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

    int nearestIndex = RouteProgressHelper.findNearestPointOnRoute(currentLatLng, _routePoints);

    if (nearestIndex > _currentRoutePointIndex) {
      setState(() {
        _currentRoutePointIndex = nearestIndex;
      });
      _updatePolylines();
      _updateNavigationInstructions();
    }
  }

  void _updatePolylines() {
    if (_routePoints.isEmpty) return;

    List<LatLng> completedRoute = _routePoints.sublist(0, _currentRoutePointIndex + 1);
    List<LatLng> remainingRoute = _routePoints.sublist(_currentRoutePointIndex);

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('completed_route'),
          points: completedRoute,
          color: Colors.grey,
          width: 6,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
        Polyline(
          polylineId: const PolylineId('remaining_route'),
          points: remainingRoute,
          color: Colors.blue,
          width: 6,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      };
    });
  }

  void _updateNavigationInstructions() {
    if (_routeSteps.isEmpty || _currentPosition == null) return;

    for (int i = 0; i < _routeSteps.length; i++) {
      var step = _routeSteps[i];
      final startLocation = step['start_location'];
      final double stepLat = (startLocation['lat'] as num).toDouble();
      final double stepLng = (startLocation['lng'] as num).toDouble();
      LatLng stepLocation = LatLng(stepLat, stepLng);

      double distanceToStep = RouteProgressHelper.distanceHaversine(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        stepLocation,
      );

      if (distanceToStep < 50 && i != _currentStepIndex) {
        setState(() {
          _currentStepIndex = i;
          _currentInstruction = _cleanHtmlTags(step['html_instructions']);
          if (i + 1 < _routeSteps.length) {
            _nextInstruction = _cleanHtmlTags(_routeSteps[i + 1]['html_instructions']);
          } else {
            _nextInstruction = '';
          }
        });

        _startInstructionDismissTimer();
        break;
      }
    }
  }

  void _updateNavigationCamera() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 18.5,
            bearing: _currentBearing,
            tilt: 45.0,
          ),
        ),
      );
    }
  }

  void _startInstructionDismissTimer() {
    _instructionDismissTimer?.cancel();
    setState(() {
      _showInstructionCard = true;
    });
    _instructionDismissTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _showInstructionCard = false;
        });
      }
    });
  }

  void _startNavigationMode() {
    setState(() {
      _isNavigating = true;
    });

    _routeUpdateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted && _isNavigating) {
        _updateRouteProgress();
      }
    });
  }

  void _updateMarkers() {
    if (_currentPosition == null || widget.destinationLat == null || widget.destinationLng == null) {
      return;
    }

    final markers = <Marker>{};

    if (_hasStartedNavigation) {
      if (_ambulanceIcon != null) {
        markers.add(
          Marker(
            markerId: const MarkerId('ambulance'),
            position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            icon: _ambulanceIcon!,
            rotation: _currentBearing,
            anchor: const Offset(0.5, 0.5),
            flat: false,
            infoWindow: InfoWindow(
              title: 'Ambulance ${widget.ambulanceId}',
              snippet: 'Speed: ${_currentSpeed.toStringAsFixed(1)} km/h',
            ),
          ),
        );
      } else {
        markers.add(
          Marker(
            markerId: const MarkerId('ambulance'),
            position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(
              title: 'Ambulance ${widget.ambulanceId}',
              snippet: 'Speed: ${_currentSpeed.toStringAsFixed(1)} km/h',
            ),
          ),
        );
      }
    } else {
      markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(
            title: 'Starting Point',
            snippet: 'Your current location',
          ),
        ),
      );
    }

    markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(widget.destinationLat!, widget.destinationLng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: widget.destination,
          snippet: 'Hospital/Emergency Location',
        ),
      ),
    );

    setState(() {
      _markers = markers;
    });
  }

  Future<void> _checkPoliceAcknowledgment(String alertId) async {
    try {
      final alertSnapshot = await FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
      )
          .ref()
          .child('traffic_clearance_alerts')
          .child(alertId)
          .once();

      if (alertSnapshot.snapshot.exists) {
        final alertData = alertSnapshot.snapshot.value as Map<dynamic, dynamic>;
        final isAcknowledged = alertData['acknowledged'] == true;

        if (isAcknowledged && mounted) {
          _acknowledgmentCheckTimer?.cancel();

          setState(() {
            _isWaitingForPolice = false;
            _isTrafficClearing = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('✅ Traffic clearance acknowledged by police!'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error checking acknowledgment: $e');
    }
  }

  Future<void> _onClearTraffic() async {
    if (!_hasStartedNavigation) return;

    setState(() {
      _isTrafficClearing = true;
      _isWaitingForPolice = true;
    });

    try {
      await FirebaseAmbulanceService.sendTrafficClearanceAlert(
        ambulanceId: widget.ambulanceId,
        destination: widget.destination,
        eta: _eta,
        distance: _distance,
        priority: widget.priority.index,
        priorityLabel: PriorityConfig.fromPriority(widget.priority).label,
        currentLocation: _currentPosition != null
            ? '${_currentPosition!.latitude}, ${_currentPosition!.longitude}'
            : 'Unknown',
        requestId: _activeRequestId,
      );

      print('✅ Traffic clearance alert sent to Firebase');

      final latestAlertSnapshot = await FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
      )
          .ref()
          .child('traffic_clearance_alerts')
          .orderByChild('ambulanceId')
          .equalTo(widget.ambulanceId)
          .limitToLast(1)
          .once();

      if (latestAlertSnapshot.snapshot.exists) {
        final alerts = latestAlertSnapshot.snapshot.value as Map;
        _lastAlertId = alerts.keys.first;

        _acknowledgmentCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
          if (_lastAlertId != null) {
            await _checkPoliceAcknowledgment(_lastAlertId!);
          }
        });
      }

    } catch (e) {
      print('❌ Error in traffic clearance: $e');
      if (mounted) {
        setState(() {
          _isTrafficClearing = false;
          _isWaitingForPolice = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send traffic clearance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final priorityConfig = PriorityConfig.fromPriority(widget.priority);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Route'), backgroundColor: Colors.red),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing navigation...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Navigation Error'), backgroundColor: Colors.red),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(_errorMessage!, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : LatLng(widget.destinationLat ?? 0, widget.destinationLng ?? 0),
              zoom: 14.0,
              bearing: 0,
              tilt: 0,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              Future.delayed(const Duration(milliseconds: 500), () {
                _fitMapBounds();
              });
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            trafficEnabled: true,
            mapType: MapType.normal,
          ),

          Positioned(
            top: 50,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: priorityConfig.backgroundColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: priorityConfig.color, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(priorityConfig.icon, color: priorityConfig.color, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    priorityConfig.label,
                    style: TextStyle(
                      color: priorityConfig.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            top: 50,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back, color: Colors.black),
            ),
          ),

          if (_hasStartedNavigation && _showInstructionCard && _currentInstruction.isNotEmpty)
            Positioned(
              top: 110,
              left: 16,
              right: 16,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.navigation, color: Colors.blue, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _currentInstruction,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              setState(() {
                                _showInstructionCard = false;
                              });
                            },
                          ),
                        ],
                      ),
                      if (_nextInstruction.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Then: $_nextInstruction',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(Icons.timer, 'ETA', _eta),
                        _buildStatItem(Icons.route, 'Distance', _distance),
                        if (_hasStartedNavigation)
                          _buildStatItem(Icons.speed, 'Speed', '${_currentSpeed.toStringAsFixed(0)} km/h'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!_hasStartedNavigation)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _onStartNavigation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow, color: Colors.white),
                              SizedBox(width: 8),
                              Text('START NAVIGATION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isTrafficClearing ? null : _onClearTraffic,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isTrafficClearing ? Colors.grey : Colors.red,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(_isTrafficClearing ? Icons.timer : Icons.traffic, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isTrafficClearing ? 'WAITING FOR POLICE' : 'CLEAR TRAFFIC',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isCompletingTrip ? null : _completeTrip,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: _isCompletingTrip
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                                  : const Text('COMPLETE TRIP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.red, size: 24),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}