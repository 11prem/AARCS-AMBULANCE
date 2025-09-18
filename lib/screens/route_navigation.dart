// screens/route_navigation.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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
  Timer? _locationTimer;
  Position? _currentPosition;
  Position? _lastPosition;
  double _currentSpeed = 0.0; // km/h
  double _totalDistance = 0.0; // km
  int _estimatedTime = 0; // minutes
  bool _isNavigating = true;
  String _nextInstruction = "Loading route...";
  List<Position> _routePositions = [];

  // Traffic simulation
  bool _showTraffic = true;
  String _trafficStatus = "Light Traffic";
  Color _trafficColor = Colors.green;

  @override
  void initState() {
    super.initState();
    _initializeNavigation();
  }

  Future<void> _initializeNavigation() async {
    await _getCurrentLocation();
    await _calculateRoute();
    _startLocationTracking();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _nextInstruction = "Location services disabled";
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _nextInstruction = "Location permission denied";
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _lastPosition = position;
      });
    } catch (e) {
      setState(() {
        _nextInstruction = "Error getting location: $e";
      });
    }
  }

  Future<void> _calculateRoute() async {
    if (_currentPosition == null) return;

    try {
      // Simulate route calculation using OpenRouteService (free alternative)
      // You can also use Google Directions API if you have an API key
      final String orsUrl =
          "https://api.openrouteservice.org/v2/directions/driving-car?"
          "api_key=YOUR_ORS_API_KEY&"
          "start=${_currentPosition!.longitude},${_currentPosition!.latitude}&"
          "end=77.2090,28.6139"; // Example destination coordinates

      // For demo purposes, we'll simulate the route data
      _simulateRouteData();
    } catch (e) {
      _simulateRouteData();
    }
  }

  void _simulateRouteData() {
    // Simulate route data for demonstration
    setState(() {
      _totalDistance = 8.2 + Random().nextDouble() * 2; // 8.2-10.2 km
      _estimatedTime = 12 + Random().nextInt(8); // 12-20 minutes
      _nextInstruction = "Head north on Main Street";
    });
  }

  void _startLocationTracking() {
    _locationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _updateLocation();
    });
  }

  Future<void> _updateLocation() async {
    if (!_isNavigating) return;

    try {
      Position newPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (_lastPosition != null) {
        // Calculate speed
        double distance = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          newPosition.latitude,
          newPosition.longitude,
        );

        double timeElapsed = 2.0; // 2 seconds
        double speedMps = distance / timeElapsed; // meters per second
        double speedKmh = speedMps * 3.6; // convert to km/h

        setState(() {
          _currentPosition = newPosition;
          _currentSpeed = speedKmh;
          _lastPosition = newPosition;

          // Update distance and time (simulate decreasing)
          _totalDistance = max(0, _totalDistance - (speedKmh / 1800)); // Approximate decrease
          _estimatedTime = (_totalDistance / max(1, speedKmh / 60)).round();

          // Simulate traffic updates
          _updateTrafficStatus();
          _updateNavigationInstructions();
        });
      } else {
        setState(() {
          _currentPosition = newPosition;
          _lastPosition = newPosition;
        });
      }
    } catch (e) {
      // Handle location update errors
    }
  }

  void _updateTrafficStatus() {
    // Simulate traffic status changes
    Random random = Random();
    int trafficLevel = random.nextInt(3);

    switch (trafficLevel) {
      case 0:
        _trafficStatus = "Light Traffic";
        _trafficColor = Colors.green;
        break;
      case 1:
        _trafficStatus = "Moderate Traffic";
        _trafficColor = Colors.orange;
        break;
      case 2:
        _trafficStatus = "Heavy Traffic";
        _trafficColor = Colors.red;
        break;
    }
  }

  void _updateNavigationInstructions() {
    // Simulate navigation instructions
    List<String> instructions = [
      "Continue straight for 500m",
      "Turn right at the next intersection",
      "Take the highway exit",
      "Keep left at the fork",
      "Your destination is ahead on the right",
    ];

    Random random = Random();
    _nextInstruction = instructions[random.nextInt(instructions.length)];
  }

  void _clearTraffic() {
    setState(() {
      _showTraffic = !_showTraffic;
    });

    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_showTraffic ? "Traffic overlay enabled" : "Traffic overlay disabled"),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _endNavigation() {
    setState(() {
      _isNavigating = false;
    });
    _locationTimer?.cancel();
    Navigator.pop(context);
  }

  Future<void> _openFullMapsApp() async {
    final Uri googleMapsUrl = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=${widget.destination}&travelmode=driving",
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Map Container (Simulated)
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade200,
                  Colors.blue.shade50,
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map,
                    size: 100,
                    color: Colors.blue.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Map View",
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.blue.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Route to: ${widget.destination}",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blue.shade500,
                    ),
                  ),
                  if (_showTraffic) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _trafficColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _trafficStatus,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Top ETA Card
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "${_estimatedTime}",
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            "MIN",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade300,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "${_totalDistance.toStringAsFixed(1)}",
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            "KM",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Speed Display
          Positioned(
            top: 160,
            right: 20,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(
                      "${_currentSpeed.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Text(
                      "km/h",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Navigation Instructions
          Positioned(
            bottom: 180,
            left: 20,
            right: 20,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.navigation,
                      color: Colors.blue,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _nextInstruction,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Controls
          Positioned(
            bottom: 60,
            left: 20,
            right: 20,
            child: Row(
              children: [
                // Clear Traffic Button
                Expanded(
                  child: GestureDetector(
                    onTap: _clearTraffic,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _showTraffic ? Icons.traffic : Icons.clear_all,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _showTraffic ? "CLEAR TRAFFIC" : "SHOW TRAFFIC",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Open Maps Button
                GestureDetector(
                  onTap: _openFullMapsApp,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Icon(
                      Icons.open_in_new,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Top Navigation Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: _endNavigation,
                          ),
                          Text(
                            widget.ambulanceId,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          isDark ? Icons.wb_sunny : Icons.nights_stay,
                          color: Colors.white,
                        ),
                        onPressed: widget.onToggleTheme,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Status indicator (Sending location)
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Sending location",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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