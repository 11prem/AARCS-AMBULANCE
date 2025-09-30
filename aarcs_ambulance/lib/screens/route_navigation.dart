// lib/screens/route_navigation.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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

  final String _apiKey = '***REMOVED***';
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _initializeNavigation();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController?.dispose();
    _routeUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeNavigation() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      await _checkLocationPermissions();
      await _getCurrentPosition();
      if (_currentPosition != null) {
        await _getDirections();
        _startLocationTracking();
      } else {
        throw Exception('Unable to get current location');
      }
    } catch (e) {
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
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      setState(() {
        _isLocationActive = true;
      });
    } catch (e) {
      try {
        _currentPosition = await Geolocator.getLastKnownPosition();
        if (_currentPosition != null) {
          setState(() {
            _isLocationActive = true;
          });
        } else {
          throw Exception('No location data available');
        }
      } catch (fallbackError) {
        throw Exception('Failed to get location: $e');
      }
    }
  }

  void _startLocationTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters for smooth progress
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
      // Calculate speed
      final double distanceInMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );

      final int deltaTime = newPosition.timestamp != null && _currentPosition!.timestamp != null
          ? newPosition.timestamp!.difference(_currentPosition!.timestamp!).inMilliseconds
          : 0;

      if (deltaTime > 0) {
        final double speedMps = distanceInMeters / (deltaTime / 1000);
        final double speedKmh = speedMps * 3.6;

        // Calculate bearing for navigation
        _currentBearing = Geolocator.bearingBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          newPosition.latitude,
          newPosition.longitude,
        );

        setState(() {
          _currentSpeed = speedKmh;
        });
      }
    }

    setState(() {
      _currentPosition = newPosition;
    });

    // Update navigation if active
    if (_isNavigating) {
      _updateNavigationProgress(newPosition);
      _updateRouteProgress(newPosition);
      _updateNavigationCamera();
    }
  }

  void _updateRouteProgress(Position position) {
    if (_routePoints.isEmpty) return;

    // Throttle updates to prevent excessive rebuilds
    _routeUpdateTimer?.cancel();
    _routeUpdateTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _computeRouteSplit(LatLng(position.latitude, position.longitude));
      }
    });
  }

  void _computeRouteSplit(LatLng currentPos) {
    if (_routePoints.isEmpty) return;

    int nearestPointIndex = RouteProgressHelper.findNearestPointOnRoute(currentPos, _routePoints);

    // Create completed polyline (grey)
    List<LatLng> completedPoints = _routePoints.take(nearestPointIndex + 1).toList();

    // Create remaining polyline (blue/red)
    List<LatLng> remainingPoints = _routePoints.skip(nearestPointIndex).toList();

    Set<Polyline> newPolylines = {};

    // Add completed route (grey) if there are completed points
    if (completedPoints.length > 1) {
      newPolylines.add(
        Polyline(
          polylineId: const PolylineId('completed_route'),
          points: completedPoints,
          color: Colors.grey.withOpacity(0.8),
          width: 6,
          zIndex: 1,
        ),
      );
    }

    // Add remaining route (colored) if there are remaining points
    if (remainingPoints.length > 1) {
      newPolylines.add(
        Polyline(
          polylineId: const PolylineId('remaining_route'),
          points: remainingPoints,
          color: Colors.blue,
          width: 6,
          zIndex: 2,
        ),
      );
    }

    setState(() {
      _polylines = newPolylines;
    });
  }

  void _updateNavigationProgress(Position position) {
    if (_routeSteps.isEmpty || _currentStepIndex >= _routeSteps.length) return;

    final currentStep = _routeSteps[_currentStepIndex];
    final stepEndLat = (currentStep['end_location']['lat'] as num).toDouble();
    final stepEndLng = (currentStep['end_location']['lng'] as num).toDouble();

    final distanceToStepEnd = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      stepEndLat,
      stepEndLng,
    );

    setState(() {
      _distanceToNextTurn = distanceToStepEnd;
    });

    // Check if we've reached the current step
    if (distanceToStepEnd < 50.0) { // 50 meters threshold
      _moveToNextStep();
    }
  }

  void _moveToNextStep() {
    if (_currentStepIndex < _routeSteps.length - 1) {
      setState(() {
        _currentStepIndex++;
        _currentInstruction = _cleanHtmlInstructions(_routeSteps[_currentStepIndex]['html_instructions']);

        if (_currentStepIndex + 1 < _routeSteps.length) {
          _nextInstruction = _cleanHtmlInstructions(_routeSteps[_currentStepIndex + 1]['html_instructions']);
        } else {
          _nextInstruction = "You will arrive at your destination";
        }
      });
    } else {
      // Reached destination
      setState(() {
        _isNavigating = false;
        _currentInstruction = "You have arrived at your destination!";
        _nextInstruction = "";
      });
    }
  }

  String _cleanHtmlInstructions(String htmlText) {
    return htmlText
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .trim();
  }

  void _updateNavigationCamera() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 18.0,
            bearing: _currentBearing,
            tilt: 45.0,
          ),
        ),
      );
    }
  }

  Future<void> _getDirections() async {
    if (_currentPosition == null) {
      throw Exception('Current position not available');
    }

    try {
      double destLat;
      double destLng;

      // Get destination coordinates
      if (widget.destinationLat != null && widget.destinationLng != null) {
        destLat = widget.destinationLat!;
        destLng = widget.destinationLng!;
      } else {
        final coordinates = await _geocodeAddress(widget.destination);
        destLat = coordinates['lat']!;
        destLng = coordinates['lng']!;
      }

      // Get directions
      final directions = await _fetchDirections(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        destLat,
        destLng,
      );

      _processDirectionsResponse(directions, destLat, destLng);

    } catch (e) {
      debugPrint('getDirections error: $e');
      throw Exception('Failed to get directions: ${e.toString()}');
    }
  }

  Future<Map<String, double>> _geocodeAddress(String address) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
          '?address=${Uri.encodeComponent(address)}'
          '&key=$_apiKey',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('Geocoding request failed');
    }

    final data = json.decode(response.body);
    if (data['status'] != 'OK' || (data['results'] as List).isEmpty) {
      throw Exception('Address not found');
    }

    final location = data['results'][0]['geometry']['location'];
    return {
      'lat': (location['lat'] as num).toDouble(),
      'lng': (location['lng'] as num).toDouble(),
    };
  }

  Future<Map<String, dynamic>> _fetchDirections(
      double originLat, double originLng, double destLat, double destLng) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=$originLat,$originLng'
          '&destination=$destLat,$destLng'
          '&key=$_apiKey'
          '&mode=driving'
          '&units=metric',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('Directions request failed');
    }

    final data = json.decode(response.body);
    if (data['status'] != 'OK' || (data['routes'] as List).isEmpty) {
      throw Exception('No routes found: ${data['status']}');
    }

    return data;
  }

  void _processDirectionsResponse(Map<String, dynamic> data, double destLat, double destLng) {
    final route = data['routes'][0];
    final leg = route['legs'][0];

    // Extract route information
    final distanceText = leg['distance']['text'];
    final durationText = leg['duration']['text'];

    // Extract steps for navigation
    _routeSteps = List<Map<String, dynamic>>.from(leg['steps']);

    // Decode polyline
    final polylinePoints = _decodePolyline(route['overview_polyline']['points']);
    _routePoints = polylinePoints;

    // Create initial single polyline for overview (before navigation starts)
    final polyline = Polyline(
      polylineId: const PolylineId('route'),
      points: polylinePoints,
      color: Colors.blue,
      width: 5,
    );

    // Create only destination marker (no start marker - use blue dot instead)
    final endMarker = Marker(
      markerId: const MarkerId('end'),
      position: LatLng(destLat, destLng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(title: widget.destination),
    );

    setState(() {
      _polylines = {polyline};
      _markers = {endMarker}; // Only destination marker
      _distance = distanceText;
      _eta = durationText;
      _isLoading = false;

      // Set initial navigation instruction
      if (_routeSteps.isNotEmpty) {
        _currentInstruction = _cleanHtmlInstructions(_routeSteps[0]['html_instructions']);
        if (_routeSteps.length > 1) {
          _nextInstruction = _cleanHtmlInstructions(_routeSteps[1]['html_instructions']);
        }
      }
    });

    // Fit camera to show entire route
    if (polylinePoints.isNotEmpty && _mapController != null) {
      _fitCameraToRoute(polylinePoints);
    }
  }

  List<LatLng> _decodePolyline(String polyline) {
    List<LatLng> points = [];
    int index = 0;
    int len = polyline.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  void _fitCameraToRoute(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (LatLng point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _startNavigation() {
    if (_routeSteps.isEmpty) return;

    setState(() {
      _isNavigating = true;
      _currentStepIndex = 0;
    });

    // Start navigation camera and route progress tracking
    if (_currentPosition != null) {
      _updateNavigationCamera();
      _computeRouteSplit(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
    }
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _currentStepIndex = 0;
      _currentInstruction = "";
      _nextInstruction = "";

      // Reset to single overview polyline
      if (_routePoints.isNotEmpty) {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: _routePoints,
            color: Colors.blue,
            width: 5,
          )
        };
      }
    });

    _routeUpdateTimer?.cancel();

    // Return to overview
    if (_routePoints.isNotEmpty) {
      _fitCameraToRoute(_routePoints);
    }
  }

  void _clearTraffic() {
    setState(() {
      _isTrafficClearing = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.local_hospital, color: Colors.white),
            SizedBox(width: 8),
            Text("🚨 Emergency traffic clearance requested"),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isTrafficClearing = false;
        });
      }
    });
  }

  Widget _buildNavigationInstructions() {
    if (!_isNavigating || _currentInstruction.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.navigation, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _currentInstruction,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_distanceToNextTurn > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_distanceToNextTurn.round()}m',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          if (_nextInstruction.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.turn_right, color: Colors.white70, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Then: $_nextInstruction',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
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
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ETA and Distance Card
            Container(
              margin: const EdgeInsets.all(12.0),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text(
                        _eta.split(' ').first,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('MIN', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                  Container(
                    height: 50,
                    width: 1,
                    color: Colors.grey[300],
                  ),
                  Column(
                    children: [
                      Text(
                        _distance.split(' ').first,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('KM', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),

            // Navigation Instructions
            _buildNavigationInstructions(),

            // Map
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _isLoading
                      ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.red),
                        SizedBox(height: 16),
                        Text('Loading route...'),
                      ],
                    ),
                  )
                      : (_currentPosition == null)
                      ? const Center(child: Text('Location not available'))
                      : GoogleMap(
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                    },
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      zoom: _isNavigating ? 18 : 14,
                      bearing: _isNavigating ? _currentBearing : 0,
                      tilt: _isNavigating ? 45 : 0,
                    ),
                    polylines: _polylines,
                    markers: _markers,
                    myLocationEnabled: true, // Blue dot enabled
                    myLocationButtonEnabled: true,
                    trafficEnabled: true,
                    compassEnabled: true,
                    rotateGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    zoomGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                  ),
                ),
              ),
            ),

            // Status and Speed
            Container(
              margin: const EdgeInsets.all(12.0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_currentSpeed.toInt()} km/h',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Current Speed',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _isLocationActive ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isLocationActive ? 'Location Active' : 'Location Inactive',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Navigation Control Buttons
            if (!_isNavigating) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12.0),
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _routeSteps.isNotEmpty ? _startNavigation : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow),
                      SizedBox(width: 8),
                      Text(
                        'START NAVIGATION',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Clear Traffic Button
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12.0),
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isTrafficClearing ? null : _clearTraffic,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isTrafficClearing
                    ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'CLEARING TRAFFIC...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
                    : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded),
                    SizedBox(width: 8),
                    Text(
                      '🚨 CLEAR TRAFFIC',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
