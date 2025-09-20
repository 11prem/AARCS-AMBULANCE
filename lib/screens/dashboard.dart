// lib/screens/dashboard.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'route_navigation.dart';
import 'dart:async';

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
  Timer? _debounce;

  // Suggestions from Google Places Autocomplete
  List<dynamic> _searchSuggestions = [];

  // Put your real API key here (or load from env)
  static const String _googleApiKey = '***REMOVED***';

  // Enhanced filtering keywords for emergency and general hospitals only
  final List<String> _allowedNameKeywords = [
    'hospital',
    'multi specialty',
    'multi speciality',
    'general hospital',
    'medical college',
    'government hospital',
    'emergency',
    'trauma center',
    'trauma centre',
    'super specialty',
    'super speciality',
    'medical center',
    'medical centre',
    'healthcare center',
    'healthcare centre',
  ];

  // Keywords to EXCLUDE specialized clinics and non-emergency facilities
  final List<String> _excludeKeywords = [
    'dental', 'ortho', 'orthopedic', 'orthopedic',
    'skin', 'dermatology', 'cosmetic', 'beauty',
    'eye', 'optical', 'vision', 'lasik',
    'ent', 'ear nose throat',
    'fertility', 'ivf',
    'psychiatry', 'psychology', 'mental health',
    'physiotherapy', 'rehab', 'rehabilitation',
    'ayurveda', 'homeopathy',
    'diagnostic', 'lab', 'pathology',
    'pharmacy', 'medical store',
    'clinic', 'polyclinic',
    'veterinary', 'pet',
    'nursing home',
  ];

  // Keywords to identify hospital suggestions for autocomplete
  final List<String> _hospitalKeywords = [
    'hospital',
    'specialty',
    'emergency',
    'medical center',
    'medical centre',
    'healthcare',
    'trauma',
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
        await Geolocator.openLocationSettings();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied')),
        );
        return;
      }

      try {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        _currentPosition = pos;
      } catch (e) {
        final last = await Geolocator.getLastKnownPosition();
        _currentPosition = last;
        debugPrint('Current position failed, using lastKnown: $e');
      }
    } catch (e) {
      debugPrint('Error determining position: $e');
    }
  }

  // Enhanced hospital filtering function
  bool _isValidHospital(String name, List<String> types) {
    final String nameLower = name.toLowerCase();

    // First, check if it contains any excluded keywords
    for (String excludeKeyword in _excludeKeywords) {
      if (nameLower.contains(excludeKeyword.toLowerCase())) {
        return false;
      }
    }

    // Check if it's a valid hospital based on name
    bool nameMatch = _allowedNameKeywords.any((kw) => nameLower.contains(kw.toLowerCase()));

    // Check if it's a valid hospital based on Google Places types
    bool typeMatch = types.any((type) =>
    type.contains('hospital') ||
        type.contains('health') ||
        type.contains('establishment')
    );

    // Must have either name match or be classified as hospital by Google
    return nameMatch || (typeMatch && !nameLower.contains('clinic'));
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
        '&radius=10000'
        '&type=hospital'
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
        final dynamic typesDynamic = place['types'];
        final List<String> types = [];

        if (typesDynamic is List) {
          for (var t in typesDynamic) {
            if (t != null) types.add(t.toString().toLowerCase());
          }
        }

        // Enhanced filtering - only include valid emergency/general hospitals
        if (!_isValidHospital(name, types)) {
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
        });
      }

      if (hospitals.isEmpty) {
        setState(() {
          nearbyHospitals = [];
        });
        return;
      }

      hospitals.sort((a, b) => (a['distance_m'] as double).compareTo(b['distance_m'] as double));
      final limited = hospitals.take(10).toList();

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

  // Enhanced autocomplete with hospital filtering
  Future<void> _fetchSearchSuggestions(String input) async {
    if (input.isEmpty) {
      setState(() => _searchSuggestions = []);
      return;
    }

    if (_currentPosition == null) {
      debugPrint('Current position not available for autocomplete');
      setState(() => _searchSuggestions = []);
      return;
    }

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=$input'
          '&types=establishment'
          '&keyword=hospital'
          '&location=${_currentPosition!.latitude},${_currentPosition!.longitude}'
          '&radius=15000'
          '&strictbounds'
          '&key=$_googleApiKey',
    );

    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final predictions = (data['predictions'] as List?) ?? [];

        final hospitalSuggestions = predictions.where((prediction) {
          final description = (prediction['description'] ?? '').toString().toLowerCase();
          final types = (prediction['types'] as List?) ?? [];

          // Enhanced filtering for autocomplete suggestions
          return _isValidHospital(description, types.map((e) => e.toString()).toList());
        }).toList();

        setState(() {
          _searchSuggestions = hospitalSuggestions;
        });
      } else {
        debugPrint('Autocomplete API error: ${resp.statusCode} - ${resp.body}');
        setState(() => _searchSuggestions = []);
      }
    } catch (e) {
      debugPrint('Autocomplete error: $e');
      setState(() => _searchSuggestions = []);
    }
  }

  void _openRouteScreenWithHospital(Map<String, dynamic> hospital) {
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RouteNavigationScreen(
          ambulanceId: widget.ambulanceId,
          destination: text,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
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
              // Header with ambulance ID and theme toggle
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

              // Destination input with enhanced autocomplete
              TextField(
                controller: _destinationController,
                onChanged: (value) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), () {
                    _fetchSearchSuggestions(value);
                  });
                },
                decoration: InputDecoration(
                  hintText: "Enter hospital destination",
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              // Search suggestions dropdown
              if (_searchSuggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchSuggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _searchSuggestions[index];
                      final description = suggestion['description'] ?? '';

                      return ListTile(
                        title: Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () async {
                          _destinationController.text = description;
                          setState(() => _searchSuggestions = []);

                          final placeId = suggestion['place_id'];
                          final detailsUrl = Uri.parse(
                            'https://maps.googleapis.com/maps/api/place/details/json'
                                '?place_id=$placeId&key=$_googleApiKey',
                          );

                          final detailsResp = await http.get(detailsUrl);
                          if (detailsResp.statusCode == 200) {
                            final detailsData = json.decode(detailsResp.body);
                            final loc = detailsData['result']['geometry']['location'];
                            final lat = loc['lat'];
                            final lng = loc['lng'];

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RouteNavigationScreen(
                                  ambulanceId: widget.ambulanceId,
                                  destination: description,
                                  destinationLat: lat,
                                  destinationLng: lng,
                                  onToggleTheme: widget.onToggleTheme,
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
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

              // Nearby Hospitals header
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

              // FIXED: Hospital list with Expanded to fill remaining space
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : nearbyHospitals.isEmpty
                    ? const Center(child: Text('No emergency hospitals found nearby', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                  padding: EdgeInsets.zero, // Remove default padding
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

  @override
  void dispose() {
    _debounce?.cancel();
    _destinationController.dispose();
    super.dispose();
  }
}