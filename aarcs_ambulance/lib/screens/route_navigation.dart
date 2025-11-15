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
  }) async {
    try {
      print('📝 Preparing Firebase write...');

      final requestRef = _database.child('emergency_requests').push();
      final requestId = requestRef.key;

      print('📝 Generated Request ID: $requestId');

      final requestData = {
        'ambulanceId': ambulanceId,
        'destination': destinationName,
        'currentLocation': 'Lat: ${currentLat.toStringAsFixed(6)}, Lng: ${currentLng.toStringAsFixed(6)}',
        'status': 'pending',
        'timestamp': ServerValue.timestamp,
        'eta': eta ?? 'N/A',
        'distance': distance ?? 'N/A',
        'sourceCoords': {
          'lat': currentLat,
          'lng': currentLng,
        },
        'destCoords': {
          'lat': destLat,
          'lng': destLng,
        },
      };

      print('📝 Writing data to Firebase...');
      print('   Path: emergency_requests/$requestId');
      print('   Data: $requestData');

      await requestRef.set(requestData);

      print('✅ Firebase write SUCCESS!');
      print('   Request ID: $requestId');

      return requestId;
    } catch (e) {
      print('❌ Firebase write FAILED: $e');
      print('   Error type: ${e.runtimeType}');
      return null;
    }
  }
}

// Helper class for route progress calculation
class RouteProgressHelper {
  static const double _earthRadius = 6371000; // meters

  static double distanceHaversine(LatLng point1, LatLng point2) {
    double lat1Rad = point1.latitude * (math.pi / 180);
    double lat2Rad = point2.latitude * (math.pi / 180);
    double deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180);
    double deltaLngRad = (point2.longitude - point1.longitude) * (math.pi / 180);

    double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);
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

  const RouteNavigationScreen({
    super.key,
    required this.ambulanceId,
    required this.destination,
    required this.destinationLat,
    required this.destinationLng,
    required this.onToggleTheme,
  });

  @override
  State<RouteNavigationScreen> createState() => _RouteNavigationScreenState();
}

class _RouteNavigationScreenState extends State<RouteNavigationScreen> {
  bool _hasCompletedTrip = false;
  String? _activeRequestId;
  bool _isCompletingTrip = false;

  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  String _eta = "--";
  String _distance = "--";
  double _currentSpeed = 0.0;
  bool _isLocationActive = false;
  bool _isTrafficClearing = false;
  bool _isLoading = true;
  String? _errorMessage;
  BitmapDescriptor? _ambulanceIcon;
  double _currentZoom = 18.5;

  // Navigation specific variables
  bool _isNavigating = false;
  List<Map<String, dynamic>> _routeSteps = [];
  int _currentStepIndex = 0;
  String _currentInstruction = "";
  String _nextInstruction = "";
  double _distanceToNextTurn = 0.0;
  double _currentBearing = 0.0;

  // Route progress tracking with dual polylines
  List<LatLng> _routePoints = [];
  int _currentRoutePointIndex = 0;
  Timer? _routeUpdateTimer;
  Timer? _instructionDismissTimer;
  bool _showInstructionCard = true;

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
    super.dispose();
  }

  // NEW: Complete Trip manually
  Future<void> _completeTrip() async {
    if (_isCompletingTrip) return;

    setState(() {
      _isCompletingTrip = true;
    });

    try {
      print('🏁 Manually completing trip...');

      // Find the active request for this ambulance
      final requestQuery = await FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
      ).ref()
          .child('emergency_requests')
          .orderByChild('ambulanceId')
          .equalTo(widget.ambulanceId)
          .limitToLast(1)
          .once();

      print('📊 Request query snapshot exists: ${requestQuery.snapshot.exists}');
      print('📊 Request query value: ${requestQuery.snapshot.value}');

      if (requestQuery.snapshot.value != null) {
        final requests = requestQuery.snapshot.value as Map;
        final requestId = requests.keys.first;
        final requestData = requests[requestId];
        final currentStatus = requestData['status'];

        print('🔍 Found request: $requestId with status: $currentStatus');

        // Update ANY pending or accepted request (not already completed or cancelled)
        if (currentStatus == 'pending' || currentStatus == 'accepted') {
          await FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
          ).ref()
              .child('emergency_requests')
              .child(requestId)
              .update({
            'status': 'completed',
            'completed_at': ServerValue.timestamp,
          });

          print('✅ Trip marked as completed: $requestId');
          print('✅ Updated Firebase with completed status');

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

            // Show dialog and navigate back after a delay
            await Future.delayed(const Duration(milliseconds: 500));
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 32),
                    SizedBox(width: 8),
                    Text('Trip Completed'),
                  ],
                ),
                content: const Text('You have successfully completed this trip. Check the History tab to see your completed trips.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pop(); // Go back to dashboard
                    },
                    child: const Text('VIEW HISTORY', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }
        } else if (currentStatus == 'completed') {
          // Already completed - just show message and go back
          print('ℹ️ Trip already completed');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ℹ️ This trip has already been completed'),
                backgroundColor: Colors.blue,
              ),
            );
            await Future.delayed(const Duration(seconds: 1));
            Navigator.of(context).pop(); // Go back to dashboard
          }
        } else {
          throw Exception('Cannot complete: Trip is ${currentStatus}');
        }
      } else {
        print('❌ No active request found for ambulance: ${widget.ambulanceId}');
        throw Exception('No active trip found. Please start a trip first.');
      }
    } catch (e) {
      print('❌ Failed to complete trip: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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

  // Add this method to check if ambulance reached destination
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

    // If within 50 meters of destination
    if (distanceToDestination < 50.0 && !_hasCompletedTrip) {
      _hasCompletedTrip = true;
      _completeTrip();
    }
  }

  Future<void> _loadCustomMarkerIcon({double zoom = 15.0}) async {
    try {
      double markerSize = 45.0;
      _ambulanceIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(
          size: Size(markerSize, markerSize),
          devicePixelRatio: 2.5,
        ),
        'assets/icons/amb.png',
      );
      print('✅ Ambulance icon loaded: ${markerSize.toInt()}px');
    } catch (e) {
      print('❌ Failed to load ambulance icon: $e');
      _ambulanceIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }

  Future<void> _initializeNavigation() async {
    try {
      print('🔄 Starting initialization...');
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      print('📍 Checking location permissions...');
      await _checkLocationPermissions();

      print('📍 Getting current position...');
      await _getCurrentPosition();

      if (_currentPosition != null) {
        print('✅ Current position: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
        print('🗺️ Getting directions...');
        await _getDirections();
        print('✅ Directions loaded, starting location tracking...');
        _startLocationTracking();
      } else {
        throw Exception('Unable to get current location');
      }
    } catch (e) {
      print('❌ Initialization error: $e');
      setState(() {
        _errorMessage = 'Initialization failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkLocationPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }
  }

  Future<void> _getCurrentPosition() async {
    try {
      print('📍 Attempting to get current position...');
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      print('✅ Position obtained: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      setState(() {
        _isLocationActive = true;
      });
    } catch (e) {
      print('⚠️ Failed to get current position, trying last known...');
      try {
        _currentPosition = await Geolocator.getLastKnownPosition();
        if (_currentPosition != null) {
          print('✅ Last known position: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
          setState(() {
            _isLocationActive = true;
          });
        } else {
          throw Exception('No location data available');
        }
      } catch (fallbackError) {
        print('❌ All location attempts failed: $e');
        throw Exception('Failed to get location: $e');
      }
    }
  }

  void _startLocationTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
          (Position position) {
        _updateLocation(position);
      },
      onError: (error) {
        debugPrint('Location stream error: $error');
      },
    );
  }

  void _updateLocation(Position newPosition) {
    if (_currentPosition != null) {
      final double distanceInMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );

      if (distanceInMeters < 10.0) {
        print('⏸️ Movement too small (${distanceInMeters.toStringAsFixed(1)}m), ignoring GPS noise');
        return;
      }

      final int deltaTime = newPosition.timestamp != null && _currentPosition!.timestamp != null
          ? newPosition.timestamp!.difference(_currentPosition!.timestamp!).inMilliseconds
          : 0;

      if (deltaTime > 0) {
        final double speedMps = distanceInMeters / (deltaTime / 1000);
        final double speedKmh = speedMps * 3.6;

        if (speedKmh > 2.0) {
          _currentBearing = Geolocator.bearingBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            newPosition.latitude,
            newPosition.longitude,
          );
        }

        setState(() {
          _currentSpeed = speedKmh;
        });
      }
    }

    LatLng snappedPosition = _snapToRoute(
        LatLng(newPosition.latitude, newPosition.longitude)
    );

    setState(() {
      _currentPosition = Position(
        latitude: snappedPosition.latitude,
        longitude: snappedPosition.longitude,
        timestamp: newPosition.timestamp,
        accuracy: newPosition.accuracy,
        altitude: newPosition.altitude,
        heading: newPosition.heading,
        speed: newPosition.speed,
        speedAccuracy: newPosition.speedAccuracy,
        altitudeAccuracy: newPosition.altitudeAccuracy,
        headingAccuracy: newPosition.headingAccuracy,
      );
    });

    _updateAmbulanceMarker();
    _sendLocationToFirebase();

    if (_isNavigating) {
      _updateRouteProgress();
      _updateNavigationCamera();
    }

    // Check if reached destination
    _checkIfReachedDestination();
  }

  LatLng _snapToRoute(LatLng currentLocation) {
    if (_routePoints.isEmpty) {
      return currentLocation;
    }

    double minDistance = double.infinity;
    LatLng nearestPoint = currentLocation;

    for (int i = 0; i < _routePoints.length; i++) {
      double distance = RouteProgressHelper.distanceHaversine(
        currentLocation,
        _routePoints[i],
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearestPoint = _routePoints[i];
      }
    }

    if (minDistance < 50.0) {
      print('📍 Snapped to route (${minDistance.toStringAsFixed(1)}m away)');
      return nearestPoint;
    }

    print('⚠️ Too far from route (${minDistance.toStringAsFixed(1)}m), using GPS');
    return currentLocation;
  }

  Future<void> _sendLocationToFirebase() async {
    if (_currentPosition == null) return;

    try {
      final requestQuery = await FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
      ).ref()
          .child('emergency_requests')
          .orderByChild('ambulanceId')
          .equalTo(widget.ambulanceId)
          .limitToLast(1)
          .once();

      if (requestQuery.snapshot.value != null) {
        final requests = requestQuery.snapshot.value as Map;
        final requestId = requests.keys.first;

        // Store the active request ID
        _activeRequestId = requestId;

        await FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
        ).ref()
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
    if (_routeSteps.isEmpty) return;

    for (int i = 0; i < _routeSteps.length; i++) {
      var step = _routeSteps[i];
      LatLng stepLocation = LatLng(
        step['start_location']['lat'],
        step['start_location']['lng'],
      );

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

    _instructionDismissTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showInstructionCard = false;
        });
      }
    });
  }

  void _updateAmbulanceMarker() {
    if (_currentPosition == null) return;

    setState(() {
      _markers = _markers.map((marker) {
        if (marker.markerId.value == 'current_location') {
          return marker.copyWith(
            positionParam: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            rotationParam: _currentBearing,
          );
        }
        return marker;
      }).toSet();
    });
  }

  Future<void> _getDirections() async {
    if (_currentPosition == null) {
      throw Exception('Current position not available');
    }

    try {
      print('🗺️ Getting directions from (${_currentPosition!.latitude}, ${_currentPosition!.longitude}) to (${widget.destinationLat}, ${widget.destinationLng})');

      double destLat;
      double destLng;

      if (widget.destinationLat != null && widget.destinationLng != null) {
        destLat = widget.destinationLat!;
        destLng = widget.destinationLng!;
      } else {
        final coordinates = await _geocodeAddress(widget.destination);
        destLat = coordinates['lat']!;
        destLng = coordinates['lng']!;
      }

      final directions = await _fetchDirections(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        destLat,
        destLng,
      );

      _processDirectionsResponse(directions, destLat, destLng);
      print('✅ Directions received successfully');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('getDirections error: $e');
      setState(() {
        _isLoading = false;
      });
      throw Exception('Failed to get directions: ${e.toString()}');
    }
  }

  Future<Map<String, double>> _geocodeAddress(String address) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$_apiKey'
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final location = data['results'][0]['geometry']['location'];
        return {
          'lat': location['lat'],
          'lng': location['lng'],
        };
      }
    }
    throw Exception('Failed to geocode address');
  }

  Future<Map<String, dynamic>> _fetchDirections(
      double startLat,
      double startLng,
      double destLat,
      double destLng,
      ) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
            'origin=$startLat,$startLng&'
            'destination=$destLat,$destLng&'
            'key=$_apiKey&'
            'mode=driving&'
            'alternatives=false'
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
        return data;
      } else {
        throw Exception('No routes found: ${data['status']}');
      }
    } else {
      throw Exception('Directions API error: ${response.statusCode}');
    }
  }

  void _processDirectionsResponse(Map<String, dynamic> directions, double destLat, double destLng) {
    if (directions['routes'] == null || directions['routes'].isEmpty) {
      throw Exception('No routes found');
    }

    final route = directions['routes'][0];
    final leg = route['legs'][0];

    setState(() {
      _eta = leg['duration']['text'];
      _distance = leg['distance']['text'];
      _routeSteps = List<Map<String, dynamic>>.from(leg['steps']);
    });

    final points = route['overview_polyline']['points'];
    final decodedPoints = _decodePolyline(points);

    setState(() {
      _routePoints = decodedPoints;
      _currentRoutePointIndex = 0;
    });

    _updatePolylines();
    _addMarkersToMap(destLat, destLng);

    if (_routeSteps.isNotEmpty) {
      setState(() {
        _currentInstruction = _cleanHtmlTags(_routeSteps[0]['html_instructions']);
        if (_routeSteps.length > 1) {
          _nextInstruction = _cleanHtmlTags(_routeSteps[1]['html_instructions']);
        }
      });
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

  void _addMarkersToMap(double destLat, double destLng) {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: _ambulanceIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          rotation: _currentBearing,
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(
            title: 'Ambulance ${widget.ambulanceId}',
            snippet: 'Current Location',
          ),
        ),
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(destLat, destLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          infoWindow: InfoWindow(
            title: widget.destination,
            snippet: 'Destination',
          ),
        ),
      };
    });
  }

  String _cleanHtmlTags(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '');
  }

  void _startNavigation() {
    setState(() {
      _isNavigating = true;
    });
    _updateNavigationCamera();
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
    });
  }

  Future<void> _clearTraffic() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Current location not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isTrafficClearing = true;
    });

    try {
      double destLat;
      double destLng;

      if (widget.destinationLat != null && widget.destinationLng != null) {
        destLat = widget.destinationLat!;
        destLng = widget.destinationLng!;
      } else {
        final coordinates = await _geocodeAddress(widget.destination);
        destLat = coordinates['lat']!;
        destLng = coordinates['lng']!;
      }

      print('🚑 CREATING FIREBASE REQUEST...');
      print('   - Ambulance ID: ${widget.ambulanceId}');
      print('   - Destination: ${widget.destination}');
      print('   - Current Position: (${_currentPosition!.latitude}, ${_currentPosition!.longitude})');
      print('   - Destination Coords: ($destLat, $destLng)');
      print('   - ETA: $_eta');
      print('   - Distance: $_distance');

      final requestId = await FirebaseAmbulanceService.sendRouteRequest(
        ambulanceId: widget.ambulanceId,
        destinationName: widget.destination,
        currentLat: _currentPosition!.latitude,
        currentLng: _currentPosition!.longitude,
        destLat: destLat,
        destLng: destLng,
        eta: _eta,
        distance: _distance,
      );

      if (requestId != null) {
        _activeRequestId = requestId;
        print('✅ REQUEST CREATED SUCCESSFULLY!');
        print('   - Request ID: $requestId');
        print('   - Check Firebase Console now!');
      } else {
        print('❌ REQUEST CREATION RETURNED NULL');
      }

      setState(() {
        _isTrafficClearing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('✅ Traffic clearing request sent to authorities'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ CRITICAL ERROR IN _clearTraffic: $e');
      print('   Stack trace: ${StackTrace.current}');

      setState(() {
        _isTrafficClearing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to send request: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Navigation - ${widget.ambulanceId}'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _initializeNavigation,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Navigation - ${widget.ambulanceId}'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          if (_isNavigating)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopNavigation,
              tooltip: 'Stop Navigation',
            )
          else
            IconButton(
              icon: const Icon(Icons.navigation),
              onPressed: _startNavigation,
              tooltip: 'Start Navigation',
            ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : (_currentPosition == null)
              ? const Center(child: Text('Location not available'))
              : ClipRRect(
            borderRadius: BorderRadius.circular(0),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                zoom: 18.5,
                bearing: 0,
                tilt: 0,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              polylines: _polylines,
              markers: _markers,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              compassEnabled: true,
              trafficEnabled: true,
              mapType: MapType.normal,
              onCameraMove: (CameraPosition position) {
                _currentZoom = position.zoom;
              },
              onCameraIdle: () async {
                await _loadCustomMarkerIcon(zoom: _currentZoom);
                _updateAmbulanceMarker();
              },
            ),
          ),

          // Info cards
          if (!_isLoading && _currentPosition != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildInfoCard('$_eta', isDark),
                  _buildInfoCard('$_distance', isDark),
                ],
              ),
            ),

          // Navigation instructions card
          if (_isNavigating && _currentInstruction.isNotEmpty && _showInstructionCard)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Dismissible(
                key: Key('instruction_$_currentStepIndex'),
                direction: DismissDirection.horizontal,
                onDismissed: (direction) {
                  setState(() {
                    _showInstructionCard = false;
                  });
                  _instructionDismissTimer?.cancel();
                  print('👆 Instruction card swiped away');
                },
                child: Card(
                  color: Colors.green,
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.arrow_upward, color: Colors.white, size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _currentInstruction,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Icon(Icons.swipe, color: Colors.white70, size: 20),
                          ],
                        ),
                        if (_nextInstruction.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Then: $_nextInstruction',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: 0.2,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Speed indicator
          if (!_isLoading)
            Positioned(
              bottom: 230,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '${_currentSpeed.toStringAsFixed(0)} km/h',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Current Speed',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

          // NEW: Complete Trip Button
          Positioned(
            bottom: 150,
            left: 16,
            right: 16,
            child: ElevatedButton.icon(
              onPressed: _isCompletingTrip ? null : _completeTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 8,
              ),
              icon: _isCompletingTrip
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Icon(Icons.check_circle, size: 24),
              label: Text(
                _isCompletingTrip ? 'COMPLETING...' : 'COMPLETE TRIP',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Clear traffic button
          Positioned(
            bottom: 80,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: _isTrafficClearing ? null : _clearTraffic,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 8,
              ),
              child: _isTrafficClearing
                  ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.warning, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'CLEAR TRAFFIC',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String text, bool isDark) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
