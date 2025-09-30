
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class EmergencyResponseScreen extends StatefulWidget {
  final Map<String, dynamic> emergencyRequest;

  const EmergencyResponseScreen({
    Key? key,
    required this.emergencyRequest,
  }) : super(key: key);

  @override
  _EmergencyResponseScreenState createState() => _EmergencyResponseScreenState();
}

class _EmergencyResponseScreenState extends State<EmergencyResponseScreen> {
  late GoogleMapController mapController;
  late Timer _timer;
  int _seconds = 0;
  String _formattedTime = '00:00';

  // Google API Key
  static const String googleApiKey = '***REMOVED***';

  PolylinePoints polylinePoints = PolylinePoints();
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _sourceLocation;
  LatLng? _destinationLocation;
  List<LatLng> _routeCoordinates = [];

  @override
  void initState() {
    super.initState();
    _startTimer();
    _initializeLocations();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
        final minutes = (_seconds ~/ 60).toString().padLeft(2, '0');
        final seconds = (_seconds % 60).toString().padLeft(2, '0');
        _formattedTime = '$minutes:$seconds';
      });
    });
  }

  void _initializeLocations() {
    // Get coordinates from emergency request data
    final sourceCoords = widget.emergencyRequest['sourceCoords'];
    final destCoords = widget.emergencyRequest['destCoords'];

    _sourceLocation = LatLng(
        sourceCoords['lat'].toDouble(),
        sourceCoords['lng'].toDouble()
    );
    _destinationLocation = LatLng(
        destCoords['lat'].toDouble(),
        destCoords['lng'].toDouble()
    );

    // Add markers
    _markers.add(
      Marker(
        markerId: const MarkerId('source'),
        position: _sourceLocation!,
        infoWindow: InfoWindow(
            title: 'Ambulance Location',
            snippet: widget.emergencyRequest['currentLocation']
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    _markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: _destinationLocation!,
        infoWindow: InfoWindow(
            title: 'Destination',
            snippet: widget.emergencyRequest['destination']
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );

    // ✅ GET ACCURATE ROUTE FROM GOOGLE DIRECTIONS API
    _getDirectionsRoute();
  }

  // ✅ ACCURATE ROUTE USING GOOGLE DIRECTIONS API
  Future<void> _getDirectionsRoute() async {
    try {
      final String url =
          'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${_sourceLocation!.latitude},${_sourceLocation!.longitude}&'
          'destination=${_destinationLocation!.latitude},${_destinationLocation!.longitude}&'
          'key=$googleApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final polylineString = route['overview_polyline']['points'];

          // Decode polyline points
          final List<PointLatLng> polylineCoords =
          polylinePoints.decodePolyline(polylineString);

          // Convert to LatLng list
          _routeCoordinates = polylineCoords
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          // Create accurate polyline
          setState(() {
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('accurate_route'),
                points: _routeCoordinates,
                color: Colors.red,
                width: 5,
                patterns: [PatternItem.dash(20), PatternItem.gap(10)],
              ),
            );
          });
        }
      }
    } catch (e) {
      print('Error getting directions: $e');
      // Fallback to straight line if API fails
      _createFallbackRoute();
    }
  }

  void _createFallbackRoute() {
    setState(() {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('fallback_route'),
          points: [_sourceLocation!, _destinationLocation!],
          color: Colors.red,
          width: 5,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;

    // Fit bounds to show both markers
    if (_sourceLocation != null && _destinationLocation != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          _sourceLocation!.latitude < _destinationLocation!.latitude
              ? _sourceLocation!.latitude : _destinationLocation!.latitude,
          _sourceLocation!.longitude < _destinationLocation!.longitude
              ? _sourceLocation!.longitude : _destinationLocation!.longitude,
        ),
        northeast: LatLng(
          _sourceLocation!.latitude > _destinationLocation!.latitude
              ? _sourceLocation!.latitude : _destinationLocation!.latitude,
          _sourceLocation!.longitude > _destinationLocation!.longitude
              ? _sourceLocation!.longitude : _destinationLocation!.longitude,
        ),
      );

      // Add padding for better view
      controller.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100.0)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildAlertMessage(),
            Expanded(
              child: _buildMap(),
            ),
            _buildControlButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Emergency Response Active',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Officer: Inspector Raggul J',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _formattedTime,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertMessage() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            color: Colors.green,
            size: 8,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ambulance approaching your zone. Clear traffic for emergency passage.',
              style: TextStyle(
                color: Colors.green[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: _sourceLocation ?? const LatLng(12.9716, 77.5946),
            zoom: 12.0,
          ),
          markers: _markers,
          polylines: _polylines,
          mapType: MapType.normal,
          zoomControlsEnabled: false,
          compassEnabled: true,
          tiltGesturesEnabled: true,
          rotateGesturesEnabled: true,
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.my_location,
            label: 'Center',
            onPressed: () {
              if (_sourceLocation != null) {
                mapController.animateCamera(
                  CameraUpdate.newLatLng(_sourceLocation!),
                );
              }
            },
          ),
          _buildControlButton(
            icon: Icons.layers,
            label: 'Layers',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Map layers feature coming soon'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          _buildControlButton(
            icon: Icons.zoom_in,
            label: 'Zoom',
            onPressed: () {
              mapController.animateCamera(CameraUpdate.zoomIn());
            },
          ),
          _buildControlButton(
            icon: Icons.search,
            label: 'Search',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Search feature coming soon'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          child: FloatingActionButton(
            onPressed: onPressed,
            backgroundColor: Colors.white,
            heroTag: label,
            elevation: 2,
            child: Icon(
              icon,
              color: Colors.black54,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
