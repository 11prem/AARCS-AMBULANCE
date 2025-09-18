import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'route_navigation.dart';

class DashboardScreen extends StatefulWidget {
  final String ambulanceId;
  final VoidCallback onToggleTheme; // ✅ Theme toggle

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

  @override
  void initState() {
    super.initState();
    _fetchNearbyHospitals();
  }

  /// Get device location + nearby hospitals
  Future<void> _fetchNearbyHospitals() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final String apiKey = "***REMOVED***"; // replace with your key
      final String url =
          "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
          "?location=${position.latitude},${position.longitude}"
          "&radius=10000"
          "&type=hospital"
          "&key=$apiKey";

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data["results"] as List;

        setState(() {
          nearbyHospitals = results
              .map((place) => place["name"] as String)
              .take(10)
              .toList(); // limit to 10
        });
      }
    } catch (e) {
      print("Error fetching hospitals: $e");
    }
  }

  /// Open Route Navigation Screen
  Future<void> _openGoogleMaps(String destination) async {
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
              // 🚑 Ambulance ID + 🌞/🌙 theme toggle
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
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Start Trip Button
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
                    if (_destinationController.text.isNotEmpty) {
                      _openGoogleMaps(_destinationController.text);
                    }
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
              const Text(
                "Nearby hospitals",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 12),

              // Hospital list
              Expanded(
                child: nearbyHospitals.isEmpty
                    ? const Center(
                  child: Text(
                    "Fetching hospitals...",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
                    : ListView.builder(
                  itemCount: nearbyHospitals.length,
                  itemBuilder: (context, index) {
                    final hospital = nearbyHospitals[index];
                    return ListTile(
                      leading: const Icon(Icons.local_hospital,
                          color: Colors.red),
                      title: Text(hospital),
                      trailing: GestureDetector(
                        onTap: () => _openGoogleMaps(hospital),
                        child: const Text(
                          "Select",
                          style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      // Bottom Navigation
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: "New Trip",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: "History",
          ),
        ],
      ),
    );
  }
}