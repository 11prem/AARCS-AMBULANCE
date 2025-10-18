import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

class EmergencyResponseScreen extends StatefulWidget {
  final Map emergencyRequest;

  const EmergencyResponseScreen({
    Key? key,
    required this.emergencyRequest,
  }) : super(key: key);

  @override
  _EmergencyResponseScreenState createState() => _EmergencyResponseScreenState();
}

class _EmergencyResponseScreenState extends State<EmergencyResponseScreen> {
  GoogleMapController? _mapController;
  Timer? _timer;
  int _seconds = 0;
  String get _formattedTime =>
      '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';
  final String _googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  LatLng? _ambulanceLocation;
  LatLng? _destinationLocation;
  String _ambulanceId = '';
  StreamSubscription? _locationSubscription;
  bool _isLoading = true;

  // ✅ NEW: Custom ambulance icon + bearing
  BitmapDescriptor? _ambulanceIcon;
  double _currentBearing = 0.0;
  double _currentSpeed = 0.0;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _initializeEverything(); // ✅ Load icon FIRST, then map
  }

// ✅ NEW: Load icon BEFORE initializing map
  Future<void> _initializeEverything() async {
    await _loadAmbulanceIcon(); // ✅ Wait for icon to load first
    await _initializeMap();      // ✅ Then initialize map
  }

// ✅ Updated: Make icon loading faster and await-able
  Future<void> _loadAmbulanceIcon() async {
    try {
      _ambulanceIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(60, 60)), // ✅ Slightly bigger for visibility
        'assets/icons/amb.png',
      );
      setState(() {}); // ✅ Force rebuild after icon loads
      print('✅ Ambulance icon loaded immediately');
    } catch (e) {
      print('⚠️ Could not load ambulance icon: $e');
    }
  }


  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  Future<void> _initializeMap() async {
    try {
      print('🗺️ Initializing map...');
      _ambulanceId = (widget.emergencyRequest['ambulanceId'] ?? 'AMB001').toString();
      print('🚑 Ambulance ID: $_ambulanceId');

      await _extractCoordinates();

      _ambulanceLocation ??= const LatLng(13.0827, 80.2707);
      _destinationLocation ??= const LatLng(13.0900, 80.2800);

      print('📍 Ambulance location: $_ambulanceLocation');
      print('📍 Destination location: $_destinationLocation');

      // ✅ Icon is already loaded, so this will work immediately
      _updateMarkers();

      await _getDirectionsRoute();
      _listenToAmbulanceLocation();

      if (mounted) {
        setState(() => _isLoading = false);
        print('✅ Map initialization complete with ambulance icon');
      }
    } catch (e, stackTrace) {
      print('❌ Error initializing map: $e');
      print('Stack trace: $stackTrace');
      _ambulanceLocation = const LatLng(13.0827, 80.2707);
      _destinationLocation = const LatLng(13.0900, 80.2800);
      _updateMarkers();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  Future<void> _extractCoordinates() async {
    try {
      final destCoords = widget.emergencyRequest['destCoords'];
      if (destCoords != null && destCoords is Map) {
        final lat = destCoords['lat'];
        final lng = destCoords['lng'];
        if (lat != null && lng != null) {
          _destinationLocation = LatLng(_parseDouble(lat), _parseDouble(lng));
        }
      }

      final sourceCoords = widget.emergencyRequest['sourceCoords'];
      if (sourceCoords != null && sourceCoords is Map) {
        final lat = sourceCoords['lat'];
        final lng = sourceCoords['lng'];
        if (lat != null && lng != null) {
          _ambulanceLocation = LatLng(_parseDouble(lat), _parseDouble(lng));
        }
      }
    } catch (e) {
      print('❌ Error in _extractCoordinates: $e');
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // ✅ Real-time Firebase sync (matches ambulance app)
  void _listenToAmbulanceLocation() {
    try {
      print('👂 Setting up Firebase listener for ambulance: $_ambulanceId');

      _locationSubscription = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
      )
          .ref()
          .child('emergency_requests')
          .orderByChild('ambulanceId')
          .equalTo(_ambulanceId)
          .limitToLast(1)
          .onValue
          .listen((event) {
        if (!mounted) return;

        try {
          if (event.snapshot.value != null) {
            final requests = event.snapshot.value as Map;
            final requestData = requests.values.first as Map;

            print('📡 Received live location update from Firebase');

            final liveLocation = requestData['liveLocation'];
            if (liveLocation != null && liveLocation is Map) {
              final lat = _parseDouble(liveLocation['lat']);
              final lng = _parseDouble(liveLocation['lng']);
              _currentBearing = _parseDouble(liveLocation['bearing'] ?? 0);
              _currentSpeed = _parseDouble(liveLocation['speed'] ?? 0);

              if (mounted) {
                setState(() {
                  _ambulanceLocation = LatLng(lat, lng);
                  _updateMarkers();

                  // ✅ Same camera behavior as ambulance app
                  _mapController?.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: _ambulanceLocation!,
                        zoom: 18.5, // ✅ Same zoom as ambulance app
                        bearing: _currentBearing,
                        tilt: 0,
                      ),
                    ),
                  );
                });
              }

              print('✅ Updated: $lat, $lng, bearing: $_currentBearing°, speed: ${_currentSpeed.toStringAsFixed(1)} km/h');
            }
          }
        } catch (e) {
          print('⚠️ Error processing Firebase data: $e');
        }
      }, onError: (error) {
        print('❌ Firebase listener error: $error');
      });

      print('✅ Firebase listener set up successfully');
    } catch (e) {
      print('❌ Error setting up Firebase listener: $e');
    }
  }

  // ✅ Update markers (custom ambulance icon + red destination)
  // ✅ Update markers - Custom ambulance icon ONLY (no blue fallback)
  void _updateMarkers() {
    if (_ambulanceLocation == null || _destinationLocation == null) return;

    if (mounted) {
      setState(() {
        _markers.clear();

        // Only add ambulance marker if custom icon loaded successfully
        if (_ambulanceIcon != null) {
          _markers.add(
            Marker(
              markerId: const MarkerId('ambulance'),
              position: _ambulanceLocation!,
              icon: _ambulanceIcon!, // ✅ Use custom icon ONLY (no fallback)
              rotation: _currentBearing,
              anchor: const Offset(0.5, 0.5),
              flat: true,
              infoWindow: InfoWindow(
                title: 'Ambulance $_ambulanceId',
                snippet: 'Speed: ${_currentSpeed.toStringAsFixed(1)} km/h',
              ),
            ),
          );
          print('✅ Ambulance marker added with custom icon');
        } else {
          print('⚠️ Ambulance icon not loaded yet, skipping marker');
        }

        // ✅ Destination in RED (hospital)
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: _destinationLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: widget.emergencyRequest['destination'] ?? 'Destination',
              snippet: 'Hospital/Emergency Location',
            ),
          ),
        );
      });
    }
  }


  Future<void> _getDirectionsRoute() async {
    if (_ambulanceLocation == null || _destinationLocation == null || _googleApiKey.isEmpty) {
      print('⚠️ Skipping directions: missing data');
      return;
    }

    try {
      final url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${_ambulanceLocation!.latitude},${_ambulanceLocation!.longitude}&'
          'destination=${_destinationLocation!.latitude},${_destinationLocation!.longitude}&'
          'mode=driving&'
          'key=$_googleApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final points = data['routes'][0]['overview_polyline']['points'];
          final decodedPoints = _decodePolyline(points);

          if (mounted) {
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
          }
          print('✅ Route added');
        }
      }
    } catch (e) {
      print('❌ Directions error: $e');
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
            Text('Loading ambulance tracking...'),
          ],
        ),
      )
          : Stack(
        children: [
          // ✅ Map with same zoom as ambulance app
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _ambulanceLocation ?? const LatLng(13.0827, 80.2707),
              zoom: 18.5, // ✅ Same zoom as ambulance app
              bearing: 0,
              tilt: 0,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              print('✅ Map created');
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
                    children: [
                      Image.asset('assets/icons/amb.png', width: 16, height: 16),
                      const SizedBox(width: 8),
                      Text('Ambulance (Live) - ${_currentSpeed.toStringAsFixed(0)} km/h',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: const [
                      Icon(Icons.local_hospital, color: Colors.red, size: 12),
                      SizedBox(width: 8),
                      Text('Hospital Destination', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
