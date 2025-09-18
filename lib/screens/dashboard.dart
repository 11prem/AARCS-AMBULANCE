// screens/dashboard.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'route_navigation.dart'; // Import the new route navigation screen

class DashboardScreen extends StatefulWidget {
  final String ambulanceId;
  final VoidCallback onToggleTheme;

  const DashboardScreen({
    super.key,
    required this.ambulanceId,
    required this.onToggleTheme,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _destinationController = TextEditingController();
  bool _isButtonPressed = false;
  List<String> nearbyHospitals = [];
  String errorMessage = "";

  @override
  void initState() {
    super.initState();
    _fetchNearbyHospitals();
  }

  /// Fetch device location first, then call free hospital API
  Future<void> _fetchNearbyHospitals() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          nearbyHospitals = _getDefaultHospitals();
          errorMessage = "Location disabled - showing nearby hospitals";
        });
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            nearbyHospitals = _getDefaultHospitals();
            errorMessage = "Location denied - showing nearby hospitals";
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          nearbyHospitals = _getDefaultHospitals();
          errorMessage = "Location permanently denied - showing nearby hospitals";
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Use the free alternative
      await fetchNearbyHospitalsFree(position.latitude, position.longitude);

    } catch (e) {
      setState(() {
        nearbyHospitals = _getDefaultHospitals();
        errorMessage = "Location error - showing nearby hospitals";
      });
    }
  }

  /// Fetch hospitals using free OpenStreetMap data via Overpass API
  Future<void> fetchNearbyHospitalsFree(double lat, double lng) async {
    // Using Overpass API (OpenStreetMap) - completely free
    final String overpassUrl =
        "https://overpass-api.de/api/interpreter?data="
        "[out:json][timeout:25];"
        "(node[amenity=hospital](around:5000,$lat,$lng);"
        "way[amenity=hospital](around:5000,$lat,$lng););"
        "out center meta;";

    try {
      final response = await http.get(Uri.parse(overpassUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Overpass API response: $data");

        if (data['elements'] != null) {
          final elements = data['elements'] as List;

          setState(() {
            nearbyHospitals = elements
                .where((element) => element['tags']?['name'] != null)
                .take(5)
                .map((element) => element['tags']['name'].toString())
                .toList()
                .cast<String>();

            // If no hospitals found, add some default ones
            if (nearbyHospitals.isEmpty) {
              nearbyHospitals = _getDefaultHospitals();
            }

            errorMessage = "";
          });
        } else {
          setState(() {
            nearbyHospitals = _getDefaultHospitals();
            errorMessage = "";
          });
        }
      } else {
        setState(() {
          nearbyHospitals = _getDefaultHospitals();
          errorMessage = "Using default hospital list";
        });
      }
    } catch (e) {
      setState(() {
        nearbyHospitals = _getDefaultHospitals();
        errorMessage = "Using offline hospital data";
      });
    }
  }

  /// Fallback hospital list for your area (Tamil Nadu) - More comprehensive
  List<String> _getDefaultHospitals() {
    return [
      "Apollo Hospital Chennai",
      "Government General Hospital",
      "MIOT International Chennai",
      "Fortis Malar Hospital",
      "Sri Ramachandra Medical Centre",
      "Stanley Medical College Hospital",
      "Rajiv Gandhi Government Hospital"
    ];
  }

  /// Navigate to Route Navigation Screen
  void _startTrip() {
    String destination = _destinationController.text.trim();

    if (destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a destination"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navigate to the route navigation screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteNavigationScreen(
          ambulanceId: widget.ambulanceId,
          destination: destination,
          onToggleTheme: widget.onToggleTheme,
        ),
      ),
    );
  }

  /// Navigate to Route Navigation Screen with selected hospital
  void _selectHospital(String hospitalName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteNavigationScreen(
          ambulanceId: widget.ambulanceId,
          destination: hospitalName,
          onToggleTheme: widget.onToggleTheme,
        ),
      ),
    );
  }

  /// Open Google Maps in drive mode (fallback option)
  Future<void> _openGoogleMaps(String destination) async {
    final Uri googleMapsUrl = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=$destination&travelmode=driving",
    );
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      throw "Could not open Google Maps.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar with Ambulance ID + 🌞/🌙 toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined,
                          color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        widget.ambulanceId,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      isDark ? Icons.wb_sunny : Icons.nights_stay,
                      color: Colors.red,
                    ),
                    onPressed: widget.onToggleTheme,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Destination input
              TextField(
                controller: _destinationController,
                decoration: const InputDecoration(
                  hintText: "Enter destination",
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Start Trip Button - Updated to navigate to route screen
              GestureDetector(
                onTapDown: (_) {
                  setState(() {
                    _isButtonPressed = true;
                  });
                },
                onTapUp: (_) {
                  Future.delayed(const Duration(milliseconds: 150), () {
                    setState(() {
                      _isButtonPressed = false;
                    });
                    _startTrip(); // Updated to call _startTrip instead of _openGoogleMaps
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 50,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color:
                    _isButtonPressed ? Colors.red.shade700 : Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    "Start Trip",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Nearby Hospitals title
              Text(
                "Nearby hospitals",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 12),

              // Hospital list or error message
              Expanded(
                child: errorMessage.isNotEmpty
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.orange),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: nearbyHospitals.length,
                        itemBuilder: (context, index) {
                          final hospital = nearbyHospitals[index];
                          return ListTile(
                            leading: const Icon(Icons.local_hospital,
                                color: Colors.red),
                            title: Text(hospital),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => _selectHospital(hospital),
                                  child: const Text(
                                    "Navigate",
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _openGoogleMaps(hospital),
                                  child: const Icon(
                                    Icons.open_in_new,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                )
                    : nearbyHospitals.isEmpty
                    ? const Text(
                  "Loading nearby hospitals...",
                  style: TextStyle(color: Colors.grey),
                )
                    : ListView.builder(
                  itemCount: nearbyHospitals.length,
                  itemBuilder: (context, index) {
                    final hospital = nearbyHospitals[index];
                    return ListTile(
                      leading: const Icon(Icons.local_hospital,
                          color: Colors.red),
                      title: Text(hospital),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _selectHospital(hospital),
                            child: const Text(
                              "Navigate",
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _openGoogleMaps(hospital),
                            child: const Icon(
                              Icons.open_in_new,
                              color: Colors.grey,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}