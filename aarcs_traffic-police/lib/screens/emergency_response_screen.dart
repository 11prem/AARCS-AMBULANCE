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

      // Get ambulance ID - with null safety
      _ambulanceId = (widget.emergencyRequest['ambulanceId'] ?? 'AMB001').toString();
      print('🚑 Ambulance ID: $_ambulanceId');

      // SAFE coordinate extraction
      await _extractCoordinates();

      // If STILL no coordinates, use Chennai defaults
      _ambulanceLocation ??= const LatLng(13.0827, 80.2707);
      _destinationLocation ??= const LatLng(13.0900, 80.2800);

      print('📍 Final ambulance location: $_ambulanceLocation');
      print('📍 Final destination location: $_destinationLocation');

      // Add markers
      _updateMarkers();

      // Get route
      await _getDirectionsRoute();

      // Listen to Firebase
      _listenToAmbulanceLocation();

      if (mounted) {
        setState(() => _isLoading = false);
        print('✅ Map initialization complete');
      }

    } catch (e, stackTrace) {
      print('❌ Error initializing map: $e');
      print('Stack trace: $stackTrace');

      // Set fallback coordinates even on error
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
      // Try to get destination coordinates
      final destCoords = widget.emergencyRequest['destCoords'];
      print('📍 destCoords raw: $destCoords (type: ${destCoords.runtimeType})');

      if (destCoords != null) {
        try {
          if (destCoords is Map) {
            final lat = destCoords['lat'];
            final lng = destCoords['lng'];

            if (lat != null && lng != null) {
              _destinationLocation = LatLng(
                _parseDouble(lat),
                _parseDouble(lng),
              );
              print('✅ Destination from destCoords: $_destinationLocation');
            }
          }
        } catch (e) {
          print('⚠️ Error parsing destCoords: $e');
        }
      }

      // Try to get source coordinates
      final sourceCoords = widget.emergencyRequest['sourceCoords'];
      print('📍 sourceCoords raw: $sourceCoords (type: ${sourceCoords.runtimeType})');

      if (sourceCoords != null) {
        try {
          if (sourceCoords is Map) {
            final lat = sourceCoords['lat'];
            final lng = sourceCoords['lng'];

            if (lat != null && lng != null) {
              _ambulanceLocation = LatLng(
                _parseDouble(lat),
                _parseDouble(lng),
              );
              print('✅ Ambulance from sourceCoords: $_ambulanceLocation');
            }
          }
        } catch (e) {
          print('⚠️ Error parsing sourceCoords: $e');
        }
      }

      // If destination still null, try geocoding destination string
      if (_destinationLocation == null) {
        final destName = widget.emergencyRequest['destination'];
        if (destName != null && destName.toString().isNotEmpty) {
          print('🔍 Geocoding destination: $destName');
          _destinationLocation = await _geocodeAddress(destName.toString());
        }
      }

      // If ambulance location still null, try geocoding current location string
      if (_ambulanceLocation == null) {
        final currentLoc = widget.emergencyRequest['currentLocation'];
        if (currentLoc != null && currentLoc.toString().isNotEmpty) {
          print('🔍 Geocoding current location: $currentLoc');
          _ambulanceLocation = await _geocodeAddress(currentLoc.toString());
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

  Future<LatLng?> _geocodeAddress(String address) async {
    if (address.isEmpty || _googleApiKey.isEmpty) return null;

    try {
      final url = 'https://maps.googleapis.com/maps/api/geocode/json'
          '?address=${Uri.encodeComponent(address)}'
          '&key=$_googleApiKey';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          final coords = LatLng(
            _parseDouble(location['lat']),
            _parseDouble(location['lng']),
          );
          print('✅ Geocoded "$address" to $coords');
          return coords;
        } else {
          print('⚠️ Geocoding API status: ${data['status']}');
        }
      }
    } catch (e) {
      print('❌ Geocoding error: $e');
    }
    return null;
  }

  void _listenToAmbulanceLocation() {
    try {
      print('👂 Starting Firebase listener for $_ambulanceId');

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
          try {
            final data = Map<String, dynamic>.from(event.snapshot.value as Map);
            final lat = data['latitude'];
            final lng = data['longitude'];

            if (lat != null && lng != null) {
              print('📍 Firebase update: $lat, $lng');

              setState(() {
                _ambulanceLocation = LatLng(_parseDouble(lat), _parseDouble(lng));
                _updateMarkers();
              });

              _mapController?.animateCamera(
                CameraUpdate.newLatLng(_ambulanceLocation!),
              );
            }
          } catch (e) {
            print('⚠️ Error processing Firebase data: $e');
          }
        }
      }, onError: (error) {
        print('❌ Firebase listener error: $error');
      });
    } catch (e) {
      print('❌ Error setting up Firebase listener: $e');
    }
  }

  void _updateMarkers() {
    _markers.clear();

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
    }

    if (_destinationLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLocation!,
          infoWindow: InfoWindow(
            title: widget.emergencyRequest['destination']?.toString() ?? 'Hospital',
            snippet: 'Destination',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
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
            Text('Loading map...'),
          ],
        ),
      )
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _ambulanceLocation ?? const LatLng(13.0827, 80.2707),
              zoom: 14,
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
                    children: const [
                      Icon(Icons.circle, color: Colors.blue, size: 12),
                      SizedBox(width: 8),
                      Text('Blue: Ambulance (Live)', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: const [
                      Icon(Icons.circle, color: Colors.red, size: 12),
                      SizedBox(width: 8),
                      Text('Red: Destination', style: TextStyle(fontSize: 12)),
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
