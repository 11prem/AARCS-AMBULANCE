import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class RouteNavigationScreen extends StatefulWidget {
  final String ambulanceId;
  final String destination;
  final VoidCallback onToggleTheme;

  const RouteNavigationScreen({
    super.key,
    required this.ambulanceId,
    required this.destination,
    required this.onToggleTheme,
  });

  @override
  State<RouteNavigationScreen> createState() => _RouteNavigationScreenState();
}

class _RouteNavigationScreenState extends State<RouteNavigationScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Position? _previousPosition;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  // Navigation data
  String _eta = "--";
  String _distance = "--";
  double _currentSpeed = 0.0;
  bool _isLocationActive = false;
  bool _isTrafficClearing = false;
  bool _isLoading = true;
  String? _errorMessage;

  // API key - replace with your actual key
  final String _apiKey = "***REMOVED***";

  Timer? _locationTimer;
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _initializeNavigation();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _positionSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeNavigation() async {
    try {
      await _checkLocationPermissions();
      await _getCurrentLocation();
      if (_currentPosition != null) {
        await _getDirections();
        _startRealTimeLocationUpdates();
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to initialize navigation: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  Future<void> _checkLocationPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are disabled. Please enable location services.';
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permissions are denied';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Location permissions are permanently denied, we cannot request permissions.';
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _currentPosition = position;
        _isLocationActive = true;
      });
    } catch (e) {
      setState(() {
        _isLocationActive = false;
      });
      throw "Error getting location: ${e.toString()}";
    }
  }

  void _startRealTimeLocationUpdates() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
          (Position position) {
        if (mounted) {
          _updateLocation(position);
        }
      },
      onError: (e) {
        setState(() {
          _isLocationActive = false;
        });
      },
    );
  }

  void _updateLocation(Position newPosition) {
    if (_currentPosition != null) {
      // Calculate speed in km/h
      double distanceInMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );

      double timeInSeconds = newPosition.timestamp!.difference(_currentPosition!.timestamp!).inSeconds.toDouble();

      if (timeInSeconds > 0) {
        double speedInMps = distanceInMeters / timeInSeconds;
        double speedInKmh = speedInMps * 3.6;

        setState(() {
          _currentSpeed = speedInKmh;
          _currentPosition = newPosition;
          _isLocationActive = true;
        });

        // Update route if significant location change
        if (distanceInMeters > 50) {
          _getDirections();
        }
      }
    } else {
      setState(() {
        _currentPosition = newPosition;
        _isLocationActive = true;
      });
    }
  }

  Future<void> _getDirections() async {
    if (_currentPosition == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1) Convert destination text to lat/lng using Geocoding API (if needed)
      double destLat;
      double destLng;

      final destText = widget.destination.trim();

      // If destination is already "lat,lng" use it directly
      final latLngMatch = RegExp(r'^\s*([-+]?\d+(\.\d+)?),\s*([-+]?\d+(\.\d+)?)\s*$')
          .firstMatch(destText);
      if (latLngMatch != null) {
        destLat = double.parse(latLngMatch.group(1)!);
        destLng = double.parse(latLngMatch.group(3)!);
      } else {
        final geocodeUrl =
            "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(destText)}&key=$_apiKey";
        final geocodeResp = await http.get(Uri.parse(geocodeUrl));
        if (geocodeResp.statusCode != 200) {
          throw 'Geocoding failed: HTTP ${geocodeResp.statusCode}';
        }
        final geoData = json.decode(geocodeResp.body);
        if (geoData['status'] != 'OK' || (geoData['results'] as List).isEmpty) {
          throw 'Geocoding failed: ${geoData['status'] ?? 'no results'}';
        }
        final loc = geoData['results'][0]['geometry']['location'];
        destLat = (loc['lat'] as num).toDouble();
        destLng = (loc['lng'] as num).toDouble();
      }

      // 2) Build Directions API request using lat/lng for origin & destination
      final origin = "${_currentPosition!.latitude},${_currentPosition!.longitude}";
      final destination = "$destLat,$destLng";

      final directionsUrl = Uri.parse(
          "https://maps.googleapis.com/maps/api/directions/json"
              "?origin=$origin"
              "&destination=$destination"
              "&key=$_apiKey"
              "&mode=driving"
              "&units=metric"
              "&avoid=tolls"
      );

      final response = await http.get(directionsUrl);

      if (response.statusCode != 200) {
        throw 'Failed to get directions: HTTP ${response.statusCode}';
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK' || (data['routes'] as List).isEmpty) {
        final apiStatus = data['status'] ?? 'UNKNOWN';
        final apiMsg = data['error_message'] ?? '';
        throw 'No routes found (status: $apiStatus) ${apiMsg}';
      }

      final route = data['routes'][0];
      final leg = route['legs'][0];

      // Extract distance and eta text
      final distanceText = leg['distance'] != null ? leg['distance']['text'] : "--";
      final durationText = leg['duration'] != null ? leg['duration']['text'] : "--";

      // Convert overview polyline to points
      final overview = route['overview_polyline']?['points'] ?? '';
      final List<LatLng> polylinePoints = overview.isNotEmpty
          ? _decodePolyline(overview)
          : <LatLng>[];

      // create polyline
      final polyline = Polyline(
        polylineId: const PolylineId('route'),
        points: polylinePoints,
        color: Colors.red,
        width: 6,
      );

      final startMarker = Marker(
        markerId: const MarkerId('start'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Start'),
      );

      final endMarker = Marker(
        markerId: const MarkerId('end'),
        position: LatLng(destLat, destLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: widget.destination),
      );

      setState(() {
        _polylines = {polyline};
        _markers = {startMarker, endMarker};
        _distance = distanceText;
        _eta = durationText;
        _isLoading = false;
        _errorMessage = null;
      });

      // Move camera to fit route if we have points
      if (polylinePoints.isNotEmpty && _mapController != null) {
        _fitCameraToRoute(polylinePoints);
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to get directions: ${e.toString()}";
        _isLoading = false;
      });
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
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100.0,
      ),
    );
  }

  void _clearTraffic() {
    setState(() {
      _isTrafficClearing = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.traffic, color: Colors.white),
            SizedBox(width: 8),
            Text("Emergency traffic clearance requested"),
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

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? "An error occurred",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _initializeNavigation();
              },
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("Navigation - ${widget.ambulanceId}"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _errorMessage != null ? _buildErrorWidget() : Column(
          children: [
            // Top ETA and Distance Card
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10.0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          _eta,
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          "MIN",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 60,
                    width: 1,
                    color: Colors.grey[300],
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          _distance,
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          "KM",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Google Map
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10.0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.0),
                  child: _isLoading
                      ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.red),
                        SizedBox(height: 16),
                        Text("Loading map..."),
                      ],
                    ),
                  )
                      : _currentPosition == null
                      ? const Center(child: Text("Location not available"))
                      : GoogleMap(
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                    },
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      zoom: 15.0,
                    ),
                    polylines: _polylines,
                    markers: _markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: false,
                    trafficEnabled: true,
                  ),
                ),
              ),
            ),

            // Speed and Location Status
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10.0,
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
                        "${_currentSpeed.toInt()} km/h",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        "Current Speed",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
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
                        _isLocationActive ? "Location Active" : "Location Inactive",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Clear Traffic Button
            Container(
              margin: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isTrafficClearing ? null : _clearTraffic,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  elevation: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isTrafficClearing)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    else
                      const Icon(Icons.warning_amber_rounded, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      _isTrafficClearing ? "CLEARING TRAFFIC..." : "🚨 CLEAR TRAFFIC",
                      style: const TextStyle(
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
      ),
    );
  }
}