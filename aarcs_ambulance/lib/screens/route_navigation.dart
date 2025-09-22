// lib/screens/route_navigation.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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

  // Put your real API key here (same key as dashboard)
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
    super.dispose();
  }

  Future<void> _initializeNavigation() async {
    try {
      await _checkLocationPermissions();
      await _determineCurrentPositionWithFallback();
      if (_currentPosition != null) {
        await _getDirections(); // will use coords if provided, otherwise geocode
        _startRealTimeLocationUpdates();
      } else {
        throw 'Location not available';
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize navigation: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkLocationPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // prompt user
      await Geolocator.openLocationSettings();
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw 'Location permissions are permanently denied';
    }
  }

  Future<void> _determineCurrentPositionWithFallback() async {
    try {
      // Try current position
      try {
        _currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      } catch (e) {
        // fallback to last known
        _currentPosition = await Geolocator.getLastKnownPosition();
        debugPrint('getCurrentPosition failed, using last known: $e');
      }

      if (_currentPosition != null) {
        setState(() {
          _isLocationActive = true;
        });
      } else {
        setState(() {
          _isLocationActive = false;
        });
        throw 'Unable to obtain location';
      }
    } catch (e) {
      rethrow;
    }
  }

  void _startRealTimeLocationUpdates() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((pos) {
      if (mounted) _updateLocation(pos);
    }, onError: (e) {
      debugPrint('Position stream error: $e');
    });
  }

  void _updateLocation(Position newPosition) {
    if (_currentPosition != null) {
      final double distanceInMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );

      final int deltaMillis = newPosition.timestamp != null && _currentPosition!.timestamp != null
          ? newPosition.timestamp!.difference(_currentPosition!.timestamp!).inMilliseconds
          : 0;

      if (deltaMillis > 0) {
        final double speedMps = distanceInMeters / (deltaMillis / 1000);
        final double speedKmh = speedMps * 3.6;
        setState(() {
          _currentSpeed = speedKmh;
          _currentPosition = newPosition;
        });

        if (distanceInMeters > 50) {
          // refresh route
          _getDirections();
        }
      } else {
        setState(() {
          _currentPosition = newPosition;
        });
      }
    } else {
      setState(() {
        _currentPosition = newPosition;
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
      double destLat;
      double destLng;

      if (widget.destinationLat != null && widget.destinationLng != null) {
        destLat = widget.destinationLat!;
        destLng = widget.destinationLng!;
      } else {
        // geocode destination string
        final geocodeUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json'
              '?address=${Uri.encodeComponent(widget.destination)}'
              '&key=$_apiKey',
        );

        final geoResp = await http.get(geocodeUrl);
        if (geoResp.statusCode != 200) {
          throw 'Geocoding failed: HTTP ${geoResp.statusCode}';
        }
        final geoData = json.decode(geoResp.body);
        if (geoData['status'] != 'OK' || (geoData['results'] as List).isEmpty) {
          throw 'Geocoding failed: ${geoData['status'] ?? 'no results'}';
        }
        final loc = geoData['results'][0]['geometry']['location'];
        destLat = (loc['lat'] as num).toDouble();
        destLng = (loc['lng'] as num).toDouble();
      }

      final origin = '${_currentPosition!.latitude},${_currentPosition!.longitude}';
      final destination = '$destLat,$destLng';

      final directionsUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json'
              '?origin=$origin'
              '&destination=$destination'
              '&key=$_apiKey'
              '&mode=driving'
              '&units=metric'
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
      final leg = (route['legs'] as List).isNotEmpty ? route['legs'][0] : null;
      final distanceText = leg != null && leg['distance'] != null ? leg['distance']['text'] : '--';
      final durationText = leg != null && leg['duration'] != null ? leg['duration']['text'] : '--';

      // decode polyline
      final overview = route['overview_polyline']?['points'] ?? '';
      final List<LatLng> polylinePoints = overview.isNotEmpty ? _decodePolyline(overview) : <LatLng>[];

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

      if (polylinePoints.isNotEmpty && _mapController != null) {
        _fitCameraToRoute(polylinePoints);
      } else if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 14),
        );
      }
    } catch (e) {
      debugPrint('getDirections error: $e');
      setState(() {
        _errorMessage = 'Failed to get directions: ${e.toString()}';
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

    for (LatLng p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
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
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_errorMessage ?? 'An error occurred', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              _initializeNavigation();
            },
            child: const Text('Retry'),
          )
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Navigation - ${widget.ambulanceId}'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _errorMessage != null
            ? _buildErrorWidget()
            : Column(children: [
          // ETA and Distance card
          Container(
            margin: const EdgeInsets.all(12.0),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(
                children: [
                  Text(_eta, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                  const Text('MIN', style: TextStyle(color: Colors.grey)),
                ],
              ),
              Container(height: 50, width: 1, color: Colors.grey[300]),
              Column(
                children: [
                  Text(_distance, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                  const Text('KM', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ]),
          ),

          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.red))
                    : (_currentPosition == null)
                    ? const Center(child: Text('Location not available'))
                    : GoogleMap(
                  onMapCreated: (c) => _mapController = c,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                    zoom: 14,
                  ),
                  polylines: _polylines,
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  trafficEnabled: true,
                ),
              ),
            ),
          ),

          // Speed and Status + Clear traffic button
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_currentSpeed.toInt()} km/h', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Text('Current Speed', style: TextStyle(color: Colors.grey)),
              ]),
              Row(children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: _isLocationActive ? Colors.green : Colors.red, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(_isLocationActive ? 'Location Active' : 'Location Inactive'),
              ]),
            ]),
          ),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12.0),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isTrafficClearing ? null : _clearTraffic,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (_isTrafficClearing) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  if (!_isTrafficClearing) const Icon(Icons.warning_amber_rounded),
                  const SizedBox(width: 8),
                  Text(_isTrafficClearing ? 'CLEARING TRAFFIC...' : '🚨 CLEAR TRAFFIC'),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}
