import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

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
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Real-time location data
  LatLng? _ambulanceLocation;
  LatLng? _destinationLocation;
  String _ambulanceId = '';

  // Firebase subscription
  StreamSubscription<DatabaseEvent>? _locationSubscription;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    print('🚓 Emergency Response Screen initialized');
    print('🚓 Emergency Request data: ${widget.emergencyRequest}');
    _startTimer();
    _initializeMap();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  Future<void> _initializeMap() async {
    try {
      print('🗺️ Initializing map...');

      // Get ambulance ID from emergency request
      _ambulanceId = widget.emergencyRequest['ambulanceId'] ?? 'AMB001';
      print('🚑 Ambulance ID: $_ambulanceId');

      // Get destination coordinates from emergency request
      final destCoords = widget.emergencyRequest['destCoords'];
      print('📍 Destination coords from request: $destCoords');

      if (destCoords != null && destCoords is Map) {
        final lat = destCoords['lat'];
        final lng = destCoords['lng'];

        if (lat != null && lng != null) {
          _destinationLocation = LatLng(
            lat is double ? lat : double.parse(lat.toString()),
            lng is double ? lng : double.parse(lng.toString()),
          );
          print('✅ Destination location set: $_destinationLocation');
        }
      }

      // Get initial ambulance location from emergency request
      final sourceCoords = widget.emergencyRequest['sourceCoords'];
      print('📍 Source coords from request: $sourceCoords');

      if (sourceCoords != null && sourceCoords is Map) {
        final lat = sourceCoords['lat'];
        final lng = sourceCoords['lng'];

        if (lat != null && lng != null) {
          _ambulanceLocation = LatLng(
            lat is double ? lat : double.parse(lat.toString()),
            lng is double ? lng : double.parse(lng.toString()),
          );
          print('✅ Ambulance location set: $_ambulanceLocation');
        }
      }

      // If coordinates not available, use fallback from current location string
      if (_ambulanceLocation == null) {
        print('⚠️ No source coords, using fallback');
        _ambulanceLocation = const LatLng(12.8546, 80.0783);
      }

      if (_destinationLocation == null) {
        print('⚠️ No destination coords, using fallback');
        _destinationLocation = const LatLng(12.9698, 80.2070);
      }

      // Add initial markers
      _updateMarkers();

      // Get route
      await _getDirectionsRoute();

      // Start listening to Firebase for real-time ambulance location
      _listenToAmbulanceLocation();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print('✅ Map initialization complete');
      }
    } catch (e) {
      print('❌ Error initializing map: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading map: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _listenToAmbulanceLocation() {
    print('👂 Starting to listen for ambulance location updates...');

    // Listen to Firebase for real-time ambulance location updates
    final databaseRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
    ).ref();

    _locationSubscription = databaseRef
        .child('ambulance_locations')
        .child(_ambulanceId)
        .onValue
        .listen((DatabaseEvent event) {
      if (event.snapshot.exists && mounted) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final lat = data['latitude'];
        final lng = data['longitude'];

        if (lat != null && lng != null) {
          print('📍 Ambulance location updated: $lat, $lng');

          setState(() {
            _ambulanceLocation = LatLng(
              lat is double ? lat : double.parse(lat.toString()),
              lng is double ? lng : double.parse(lng.toString()),
            );
            _updateMarkers();
          });

          // Update camera to follow ambulance
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(_ambulanceLocation!),
          );
        }
      } else {
        print('⚠️ No ambulance location data in Firebase');
      }
    }, onError: (error) {
      print('❌ Error listening to Firebase: $error');
    });
  }

  void _updateMarkers() {
    _markers.clear();

    // Add ambulance marker (BLUE)
    if (_ambulanceLocation != null) {
      _markers.add(
        Marker(
          markerId: MarkerId('ambulance_$_ambulanceId'),
          position: _ambulanceLocation!,
          infoWindow: InfoWindow(
            title: 'Ambulance $_ambulanceId',
            snippet: 'Current Location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
      print('🔵 Blue ambulance marker added at $_ambulanceLocation');
    }

    // Add destination marker (RED)
    if (_destinationLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLocation!,
          infoWindow: InfoWindow(
            title: widget.emergencyRequest['destination'] ?? 'Hospital',
            snippet: 'Destination',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
      print('🔴 Red destination marker added at $_destinationLocation');
    }
  }

  Future<void> _getDirectionsRoute() async {
    if (_ambulanceLocation == null || _destinationLocation == null) {
      print('⚠️ Cannot get route: missing coordinates');
      return;
    }

    print('🗺️ Fetching route from $_ambulanceLocation to $_destinationLocation');

    final url = 'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${_ambulanceLocation!.latitude},${_ambulanceLocation!.longitude}&'
        'destination=${_destinationLocation!.latitude},${_destinationLocation!.longitude}&'
        'mode=driving&'
        'key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final points = data['routes'][0]['overview_polyline']['points'];
          final decodedPoints = _decodePolyline(points);

          setState(() {
            _polylines.clear();
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                points: decodedPoints,
                color: Colors.blue,
                width: 5,
              ),
            );
          });
          print('✅ Route polyline added with ${decodedPoints.length} points');
        } else {
          print('⚠️ Directions API status: ${data['status']}');
        }
      } else {
        print('❌ Directions API error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting directions: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Emergency Response',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'Tracking $_ambulanceId',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _formattedTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading map...'),
          ],
        ),
      )
          : Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _ambulanceLocation ?? const LatLng(12.8546, 80.0783),
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              print('✅ Map controller created');
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            compassEnabled: true,
            trafficEnabled: true,
            mapType: MapType.normal,
          ),

          // Info Card at top
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.medical_services,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ambulance: $_ambulanceId',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'En route to ${widget.emergencyRequest['destination'] ?? 'Hospital'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Icon(Icons.circle, color: Colors.blue, size: 12),
                      SizedBox(width: 8),
                      Text(
                        'Blue: Ambulance (Live)',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: const [
                      Icon(Icons.circle, color: Colors.red, size: 12),
                      SizedBox(width: 8),
                      Text(
                        'Red: Destination',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Status Badge at bottom
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Traffic Clearance Active',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
}
