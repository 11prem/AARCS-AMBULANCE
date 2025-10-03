import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;

class EmergencyResponseScreen extends StatefulWidget {
  final Map<String, dynamic> emergencyRequest;

  const EmergencyResponseScreen({
    Key? key,
    required this.emergencyRequest,
  }) : super(key: key);

  @override
  _EmergencyResponseScreenState createState() =>
      _EmergencyResponseScreenState();
}

class _EmergencyResponseScreenState extends State<EmergencyResponseScreen> {
  // Controllers
  GoogleMapController? _mapController;
  Timer? _timer;

  // Stopwatch state
  int _seconds = 0;
  String get _formattedTime =>
      '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';

  // Google Maps data
  final String _googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  final PolylinePoints _polylinePoints = PolylinePoints();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _routeCoordinates = [];

  // Real-time location data
  LatLng? _currentLocation;
  LatLng? _destinationLocation;
  String? _estimatedTime;
  String? _distance;

  // Your specific addresses
  final String _currentAddress = "21st cross street, Padmavathy nagar main rd, padmavathy nagar, madambakkam, chennai, tamil nadu 600126";
  final String _destinationAddress = "Bharath Hospital, 72, 1st Main Road, Nanganallur, Chennai, Tamil Nadu 600061";

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _initializeRealTimeLocations();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  // Convert addresses to coordinates using Google Geocoding API
  Future<LatLng?> _getCoordinatesFromAddress(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final url = 'https://maps.googleapis.com/maps/api/geocode/json?address=$encodedAddress&key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return LatLng(location['lat'], location['lng']);
        }
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
    return null;
  }

  Future<void> _initializeRealTimeLocations() async {
    try {
      // Get coordinates from your specific addresses
      _currentLocation = await _getCoordinatesFromAddress(_currentAddress);
      _destinationLocation = await _getCoordinatesFromAddress(_destinationAddress);

      // Fallback coordinates if geocoding fails
      _currentLocation ??= const LatLng(12.8546, 80.0783); // Madambakkam area
      _destinationLocation ??= const LatLng(12.9698, 80.2070); // Bharath Hospital Nanganallur

      if (mounted) {
        _addMarkers();
        await _getDirectionsRoute();
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error loading locations: $e');
      }
    }
  }

  void _addMarkers() {
    _markers.clear();

    if (_currentLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          infoWindow: const InfoWindow(
            title: 'Ambulance Location',
            snippet: 'Padmavathy Nagar, Madambakkam',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    if (_destinationLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLocation!,
          infoWindow: const InfoWindow(
            title: 'Bharath Hospital',
            snippet: 'Nanganallur, Chennai - 600061',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }
  }

  Future<void> _getDirectionsRoute() async {
    if (_currentLocation == null || _destinationLocation == null) return;

    final url = 'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${_currentLocation!.latitude},${_currentLocation!.longitude}&'
        'destination=${_destinationLocation!.latitude},${_destinationLocation!.longitude}&'
        'mode=driving&'
        'traffic_model=best_guess&'
        'departure_time=now&'
        'key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];

          // Get route polyline
          final points = route['overview_polyline']['points'];
          final decoded = _polylinePoints.decodePolyline(points);

          _routeCoordinates.clear();
          _routeCoordinates.addAll(
              decoded.map((p) => LatLng(p.latitude, p.longitude)).toList()
          );

          // Extract distance and duration
          final leg = route['legs'][0];
          _distance = leg['distance']['text'];
          _estimatedTime = leg['duration_in_traffic']?['text'] ?? leg['duration']['text'];

          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: _routeCoordinates,
              color: Colors.blue,
              width: 6,
            ),
          );

          if (mounted) {
            setState(() {});
            _fitCameraToRoute();
          }
          return;
        }
      }
    } catch (e) {
      print('Directions error: $e');
    }

    // Fallback: direct line if API fails
    _createFallbackRoute();
  }

  void _createFallbackRoute() {
    if (_currentLocation == null || _destinationLocation == null) return;

    _polylines.clear();
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('fallback'),
        points: [_currentLocation!, _destinationLocation!],
        color: Colors.blue,
        width: 6,
      ),
    );

    // Calculate approximate distance using Haversine formula
    final distanceInMeters = _calculateDistance(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      _destinationLocation!.latitude,
      _destinationLocation!.longitude,
    );

    _distance = '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    _estimatedTime = '${((distanceInMeters / 1000) / 30 * 60).round()} min'; // Assuming 30 km/h average

    if (mounted) setState(() {});
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth radius in meters

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  void _fitCameraToRoute() {
    if (_routeCoordinates.isEmpty || _mapController == null) return;

    double minLat = _routeCoordinates.first.latitude;
    double maxLat = minLat;
    double minLng = _routeCoordinates.first.longitude;
    double maxLng = minLng;

    for (final point in _routeCoordinates) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading real-time route...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildRouteInfo(),
            Expanded(child: _buildMap()),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency Response Active',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Route: Madambakkam → Bharath Hospital',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _formattedTime,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.navigation, color: Colors.green, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Distance: ${_distance ?? "Calculating..."} • ETA: ${_estimatedTime ?? "Calculating..."}',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Real-time traffic route to Bharath Hospital',
                  style: TextStyle(
                    color: Colors.green[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GoogleMap(
        onMapCreated: (controller) => _mapController = controller,
        initialCameraPosition: CameraPosition(
          target: _currentLocation ?? const LatLng(12.8546, 80.0783),
          zoom: 12,
        ),
        markers: _markers,
        polylines: _polylines,
        mapType: MapType.normal,
        trafficEnabled: true,
        zoomControlsEnabled: false,
        compassEnabled: true,
        myLocationButtonEnabled: false,
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _controlBtn(
            icon: Icons.my_location,
            label: 'Current',
            onPressed: () {
              if (_currentLocation != null && _mapController != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(_currentLocation!, 15),
                );
              }
            },
          ),
          _controlBtn(
            icon: Icons.local_hospital,
            label: 'Hospital',
            onPressed: () {
              if (_destinationLocation != null && _mapController != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(_destinationLocation!, 15),
                );
              }
            },
          ),
          _controlBtn(
            icon: Icons.route,
            label: 'Full Route',
            onPressed: () => _fitCameraToRoute(),
          ),
          _controlBtn(
            icon: Icons.refresh,
            label: 'Refresh',
            onPressed: () {
              setState(() => _isLoading = true);
              _getDirectionsRoute();
            },
          ),
        ],
      ),
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: FloatingActionButton(
            heroTag: label,
            backgroundColor: Colors.white,
            elevation: 2,
            onPressed: onPressed,
            child: Icon(icon, color: Colors.black54, size: 20),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}
