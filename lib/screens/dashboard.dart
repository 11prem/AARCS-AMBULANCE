// lib/screens/dashboard.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'route_navigation.dart';

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
  bool _isLoading = false;

  Position? _currentPosition;
  List<Map<String, dynamic>> nearbyHospitals = [];

  // Put your real API key here (or load from env)
  static const String _googleApiKey = '***REMOVED***';

  // Allowed keywords (lowercase) to accept names that are hospital-like
  final List<String> _allowedNameKeywords = [
    'hospital',
    'medical center',
    'medical centre',
    'medical college',
    'medical institution',
    'medical institution',
    'multi-specialty',
    'multispecialty',
    'multi super-specialty',
    'multi-super-specialty',
    'health city',
    'health center',
    'health centre',
    'medical institution',
    'medical institute'
  ];

  @override
  void initState() {
    super.initState();
    _refreshLocationAndHospitals();
  }

  Future<void> _refreshLocationAndHospitals() async {
    setState(() {
      _isLoading = true;
    });
    await _determinePositionWithFallback();
    await _fetchNearbyHospitals();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _determinePositionWithFallback() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Request user to enable; try to open settings
        await Geolocator.openLocationSettings();
        // still continue - last known may exist
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        // cannot request
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied')),
        );
        return;
      }

      // Try getting precise current position; if times out, fallback to last-known
      try {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        _currentPosition = pos;
      } catch (e) {
        // fallback
        final last = await Geolocator.getLastKnownPosition();
        _currentPosition = last;
        debugPrint('Current position failed, using lastKnown: $e');
      }
    } catch (e) {
      debugPrint('Error determining position: $e');
      // leave _currentPosition possibly null
    }
  }

  Future<void> _fetchNearbyHospitals() async {
    nearbyHospitals = [];
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location not available to find hospitals")),
      );
      return;
    }

    final placesUrl =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?'
        'location=${_currentPosition!.latitude},${_currentPosition!.longitude}'
        '&radius=5000'
        '&type=hospital' // still ask for hospital type
        '&key=$_googleApiKey';

    try {
      setState(() => _isLoading = true);

      final resp = await http.get(Uri.parse(placesUrl));
      if (resp.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to fetch hospitals. Try again later.")),
        );
        return;
      }

      final data = json.decode(resp.body);
      final results = (data['results'] as List?) ?? [];

      // Build hospitals list, filter and compute distance, skip if lat/lng missing
      final List<Map<String, dynamic>> hospitals = [];
      for (var place in results) {
        final geometry = place['geometry'];
        final loc = geometry?['location'];
        if (loc == null) continue;

        final num? latNum = loc['lat'];
        final num? lngNum = loc['lng'];
        if (latNum == null || lngNum == null) continue;

        final double lat = latNum.toDouble();
        final double lng = lngNum.toDouble();

        final String name = (place['name'] ?? '').toString();
        final String placeId = (place['place_id'] ?? '').toString();
        final String vicinity = (place['vicinity'] ?? '').toString();
        final double rating = (place['rating'] is num) ? (place['rating'] as num).toDouble() : 0.0;

        // Filter by types OR name keyword
        final dynamic typesDynamic = place['types'];
        final List<String> types = [];
        if (typesDynamic is List) {
          for (var t in typesDynamic) {
            if (t != null) types.add(t.toString().toLowerCase());
          }
        }

        final bool isTypeHospital = types.contains('hospital') || types.contains('health');
        final String nameLower = name.toLowerCase();
        final bool nameMatch = _allowedNameKeywords.any((kw) => nameLower.contains(kw));

        if (!isTypeHospital && !nameMatch) {
          // skip clinics / shops / non-hospitals
          continue;
        }

        final double distanceMeters = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          lat,
          lng,
        );

        hospitals.add({
          'name': name,
          'place_id': placeId,
          'address': vicinity,
          'lat': lat,
          'lng': lng,
          'rating': rating,
          'distance_m': distanceMeters,
          'distance_text': (distanceMeters / 1000).toStringAsFixed(2) + ' km',
          // 'duration_text' to be filled with Distance Matrix
        });
      }

      if (hospitals.isEmpty) {
        setState(() {
          nearbyHospitals = [];
        });
        return;
      }

      // Sort by distance ascending
      hospitals.sort((a, b) => (a['distance_m'] as double).compareTo(b['distance_m'] as double));

      // take top 10
      final limited = hospitals.take(10).toList();

      // Use Distance Matrix API to fetch durations for each destination in a single call
      try {
        final origin = '${_currentPosition!.latitude},${_currentPosition!.longitude}';
        final destinations = limited.map((h) => '${h['lat']},${h['lng']}').join('|');

        final dmUrl = Uri.parse(
            'https://maps.googleapis.com/maps/api/distancematrix/json'
                '?origins=$origin'
                '&destinations=$destinations'
                '&key=$_googleApiKey'
                '&mode=driving'
                '&units=metric'
        );

        final dmResp = await http.get(dmUrl);
        if (dmResp.statusCode == 200) {
          final dmData = json.decode(dmResp.body);
          if ((dmData['rows'] is List) && dmData['rows'].isNotEmpty) {
            final elements = (dmData['rows'][0]['elements'] as List?) ?? [];
            for (int i = 0; i < limited.length && i < elements.length; i++) {
              final el = elements[i];
              final durationText = (el['duration'] != null) ? el['duration']['text'] : '--';
              final distanceTxt = (el['distance'] != null) ? el['distance']['text'] : limited[i]['distance_text'];
              limited[i]['duration_text'] = durationText;
              limited[i]['distance_text'] = distanceTxt;
            }
          }
        }
      } catch (e) {
        debugPrint('Distance Matrix failed: $e');
        // fallback: leave duration_text empty or estimate later
        for (var h in limited) {
          h['duration_text'] = '--';
        }
      }

      setState(() {
        nearbyHospitals = limited;
      });
    } catch (e) {
      debugPrint('Error fetching hospitals: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong while fetching hospitals")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openRouteScreenWithHospital(Map<String, dynamic> hospital) {
    // navigate and pass coords and name
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RouteNavigationScreen(
          ambulanceId: widget.ambulanceId,
          destination: hospital['name'] ?? '',
          destinationLat: (hospital['lat'] as double),
          destinationLng: (hospital['lng'] as double),
          onToggleTheme: widget.onToggleTheme,
        ),
      ),
    );
  }

  void _openRouteScreenFromInput() {
    final text = _destinationController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter destination name or coordinates')),
      );
      return;
    }

    // If user entered coordinates like "12.3456,78.9012"
    final latLngMatch = RegExp(r'^\s*([-+]?\d+(\.\d+)?),\s*([-+]?\d+(\.\d+)?)\s*$')
        .firstMatch(text);
    if (latLngMatch != null) {
      final lat = double.tryParse(latLngMatch.group(1)!);
      final lng = double.tryParse(latLngMatch.group(3)!);
      if (lat == null || lng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid coordinates')),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RouteNavigationScreen(
            ambulanceId: widget.ambulanceId,
            destination: text,
            destinationLat: lat,
            destinationLng: lng,
            onToggleTheme: widget.onToggleTheme,
          ),
        ),
      );
      return;
    }

    // Otherwise pass the text (name) and let RouteNavigationScreen geocode it
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RouteNavigationScreen(
          ambulanceId: widget.ambulanceId,
          destination: text,
          // pass null to let route screen geocode
          destinationLat: null,
          destinationLng: null,
          onToggleTheme: widget.onToggleTheme,
        ),
      ),
    );
  }

  Widget _buildHospitalCard(Map<String, dynamic> hospital) {
    final name = hospital['name'] ?? '--';
    final distanceText = (hospital['distance_text'] ?? '--').toString();
    final durationText = (hospital['duration_text'] ?? '--').toString();

    return InkWell(
      onTap: () => _openRouteScreenWithHospital(hospital),
      child: Card(
        color: Theme.of(context).cardColor,
        elevation: 3,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
          child: Row(
            children: [
              // left area: name + distance (stacked)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top-left name
                    Text(
                      name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    // distance left bottom
                    Row(
                      children: [
                        const Icon(Icons.place, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          distanceText,
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // right area: ETA
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'ETA',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    durationText,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(widget.ambulanceId, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(
                    icon: Icon(isDark ? Icons.wb_sunny : Icons.nights_stay, color: Colors.red),
                    onPressed: widget.onToggleTheme,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Destination input
              TextField(
                controller: _destinationController,
                decoration: InputDecoration(
                  hintText: "Enter destination (name or lat,lng)",
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.navigation, color: Colors.red),
                    onPressed: _openRouteScreenFromInput,
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              const SizedBox(height: 12),

              // Start Trip button
              GestureDetector(
                onTapDown: (_) => setState(() => _isButtonPressed = true),
                onTapUp: (_) {
                  Future.delayed(const Duration(milliseconds: 120), () {
                    setState(() => _isButtonPressed = false);
                    _openRouteScreenFromInput();
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  height: 48,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _isButtonPressed ? Colors.red.shade700 : Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Text('Start Trip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 18),

              // Nearby Hospitals header + refresh icon
              Row(
                children: [
                  const Text('Nearby Hospitals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh nearby hospitals',
                    icon: const Icon(Icons.refresh, color: Colors.red),
                    onPressed: _refreshLocationAndHospitals,
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : nearbyHospitals.isEmpty
                    ? const Center(child: Text('No hospitals found', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                  itemCount: nearbyHospitals.length,
                  itemBuilder: (context, index) {
                    final hospital = nearbyHospitals[index];
                    return _buildHospitalCard(hospital);
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
