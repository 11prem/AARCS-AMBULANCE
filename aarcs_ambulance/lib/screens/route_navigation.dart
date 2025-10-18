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

  static Future<void> sendRouteRequest({
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
      final requestId = DateTime.now().millisecondsSinceEpoch.toString();

      await _database.child('emergency_requests').child(requestId).set({
        'ambulanceId': ambulanceId,
        'destination': destinationName,
        'currentLocation': 'Lat: ${currentLat.toStringAsFixed(4)}, Lng: ${currentLng.toStringAsFixed(4)}',
        'eta': eta ?? 'Calculating...',
        'distance': distance ?? 'N/A',
        'sourceCoords': {
          'lat': currentLat,
          'lng': currentLng,
        },
        'destCoords': {
          'lat': destLat,
          'lng': destLng,
        },
        'status': 'pending',
        'timestamp': ServerValue.timestamp,
      });

      print('✅ Route request sent to Firebase: $requestId');
    } catch (e) {
      print('❌ Failed to send route request: $e');
      rethrow;
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

  Future<void> _loadCustomMarkerIcon({double zoom = 15.0}) async {
    try {
      // ✅ UBER-STYLE: Fixed 45px size (professional, compact)
      double markerSize = 45.0;

      _ambulanceIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(
          size: Size(markerSize, markerSize),
          devicePixelRatio: 2.5, // High quality on all devices
        ),
        'assets/icons/amb.png',
      );
      print('✅ Ambulance icon loaded: ${markerSize.toInt()}px');
    } catch (e) {
      print('❌ Failed to load ambulance icon: $e');
      _ambulanceIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }




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
    _instructionDismissTimer?.cancel(); // ✅ NEW: Cleanup dismiss timer
    super.dispose();
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
      debugPrint('Initialization error: $e');
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
      distanceFilter: 10, // ✅ Changed from 5 to 10 meters (less jittery)
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

      // ✅ FIX 1: Ignore GPS noise - Only update if moved more than 10 meters
      if (distanceInMeters < 10.0) {
        print('⏸️ Movement too small (${ distanceInMeters.toStringAsFixed(1)}m), ignoring GPS noise');
        return; // Don't update marker for small movements
      }

      final int deltaTime = newPosition.timestamp != null && _currentPosition!.timestamp != null
          ? newPosition.timestamp!.difference(_currentPosition!.timestamp!).inMilliseconds
          : 0;

      if (deltaTime > 0) {
        final double speedMps = distanceInMeters / (deltaTime / 1000);
        final double speedKmh = speedMps * 3.6;

        // ✅ FIX 2: Only update bearing if actually moving (speed > 2 km/h)
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

    // ✅ FIX 3: Snap ambulance to route (blue line) instead of raw GPS
    LatLng snappedPosition = _snapToRoute(
        LatLng(newPosition.latitude, newPosition.longitude)
    );

    setState(() {
      // Use snapped position instead of raw GPS
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

    // Update marker position
    _updateAmbulanceMarker();

    if (_isNavigating) {
      _updateRouteProgress();
      _updateNavigationCamera();
    }
  }

  // ✅ Snap GPS location to the nearest point on the blue route
  LatLng _snapToRoute(LatLng currentLocation) {
    if (_routePoints.isEmpty) {
      return currentLocation; // No route yet, use raw GPS
    }

    // Find nearest point on the route
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

    // Only snap if GPS is within 50 meters of route (avoid snapping if way off route)
    if (minDistance < 50.0) {
      print('📍 Snapped to route (${minDistance.toStringAsFixed(1)}m away)');
      return nearestPoint;
    }

    print('⚠️ Too far from route (${minDistance.toStringAsFixed(1)}m), using GPS');
    return currentLocation; // Too far off route, use raw GPS
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

  // ✅ UPDATED: Changed to solid lines (removed patterns)
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
          // ✅ REMOVED: patterns parameter for solid line
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

        // ✅ NEW: Show card and start auto-dismiss timer
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

  // Auto-dismiss instruction card after 5 seconds
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


  // Method to update ambulance marker position in real-time
  void _updateAmbulanceMarker() {
    if (_currentPosition == null) return;

    setState(() {
      // Find and update only the ambulance marker, keep destination marker unchanged
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

  // ✅ UPDATED: Changed destination marker to cyan (glowing blue like Google Maps)
  void _addMarkersToMap(double destLat, double destLng) {
    setState(() {
      _markers = {
        // 🚑 Ambulance marker with custom icon and rotation
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: _ambulanceIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          rotation: _currentBearing, // Rotates ambulance in movement direction
          anchor: const Offset(0.5, 0.5), // Center rotation point
          infoWindow: InfoWindow(
            title: 'Ambulance ${widget.ambulanceId}',
            snippet: 'Current Location',
          ),
        ),

        // 🏥 Destination marker (unchanged)
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

      print('🚑 Sending route clearance request to Firebase...');
      print('   - Ambulance: ${widget.ambulanceId}');
      print('   - Destination: ${widget.destination}');
      print('   - Current: (${_currentPosition!.latitude}, ${_currentPosition!.longitude})');
      print('   - Destination Coords: ($destLat, $destLng)');
      print('   - ETA: $_eta');
      print('   - Distance: $_distance');

      await FirebaseAmbulanceService.sendRouteRequest(
        ambulanceId: widget.ambulanceId,
        destinationName: widget.destination,
        currentLat: _currentPosition!.latitude,
        currentLng: _currentPosition!.longitude,
        destLat: destLat,
        destLng: destLng,
        eta: _eta,
        distance: _distance,
      );

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
      print('❌ Error sending traffic clearance: $e');

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

              // ✅ NEW: Track zoom level changes
              onCameraMove: (CameraPosition position) {
                _currentZoom = position.zoom;
              },

              // ✅ NEW: Reload marker icon when zoom stops
              onCameraIdle: () async {
                await _loadCustomMarkerIcon(zoom: _currentZoom);
                _updateAmbulanceMarker();
              },
            ),
          ),

          // ✅ UPDATED: Fixed info cards - now shows "min" and "KM" only
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
          // ✅ NEW: Swipeable Navigation instructions card with auto-dismiss
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
                            // ✅ NEW: Swipe indicator
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
                        // ✅ NEW: Auto-dismiss countdown indicator
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: 0.2, // Visual indicator (optional)
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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
              bottom: 150,
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

          // Clear traffic button
          Positioned(
            bottom: 16,
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
