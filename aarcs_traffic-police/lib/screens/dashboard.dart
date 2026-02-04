// lib/screens/dashboard.dart - TRAFFIC POLICE DASHBOARD WITH LOCAL NOTIFICATIONS

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'emergency_response_screen.dart';
import 'history_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/priority_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Local Notification Service - WORKING VERSION FOR 14.1.5
class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Notification clicked: ${response.payload}');
        // DON'T navigate to any screen - just open the app
        // The dashboard will already show the request
      },
    );
  }

  static Future<void> showTrafficAlert(
      String ambulanceId,
      String destination,
      String alertId,
      ) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'traffic_channel',
      'Traffic Alerts',
      channelDescription: 'Traffic clearance alerts',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Ambulance Alert',
    );

    const DarwinNotificationDetails iosPlatformChannelSpecifics =
    DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      0,
      '🚨 TRAFFIC CLEARANCE REQUEST',
      'Ambulance $ambulanceId needs immediate clearance to $destination',
      platformChannelSpecifics,
      payload: alertId,
    );
  }
}

// Firebase Police Service
class FirebasePoliceService {
  static final DatabaseReference _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
    'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
  ).ref();

  static Stream<DatabaseEvent> listenToEmergencyRequests() {
    return _database
        .child('emergency_requests')
        .orderByChild('timestamp')
        .limitToLast(5)
        .onValue;
  }

  static Stream<DatabaseEvent> listenToTrafficClearanceAlerts() {
    return _database
        .child('traffic_clearance_alerts')
        .orderByChild('timestamp')
        .limitToLast(5)
        .onValue;
  }

  static Future<void> acknowledgeTrafficAlert(
      String alertId, String policeId) async {
    await _database.child('traffic_clearance_alerts').child(alertId).update({
      'acknowledged': true,
      'acknowledgedBy': policeId,
      'acknowledgedAt': ServerValue.timestamp,
      'status': 'acknowledged',
    });
  }

  static Future<void> acceptRequest(String requestId) async {
    await _database.child('emergency_requests').child(requestId).update({
      'status': 'accepted',
      'acceptedAt': ServerValue.timestamp,
    });
  }

  static Future<Map<String, dynamic>?> getLatestActiveAlert() async {
    try {
      final snapshot = await _database
          .child('traffic_clearance_alerts')
          .orderByChild('status')
          .equalTo('active')
          .limitToLast(1)
          .once();

      if (snapshot.snapshot.exists) {
        final alerts = snapshot.snapshot.value as Map<dynamic, dynamic>;
        final alertId = alerts.keys.first;
        final alertData = Map<String, dynamic>.from(alerts[alertId] as Map);
        return {
          'alertId': alertId,
          'data': alertData,
        };
      }
    } catch (e) {
      print('❌ Error getting latest alert: $e');
    }
    return null;
  }
}

class AARCSTrafficPoliceDashboard extends StatefulWidget {
  @override
  _AARCSTrafficPoliceDashboardState createState() =>
      _AARCSTrafficPoliceDashboardState();
}

class _AARCSTrafficPoliceDashboardState
    extends State<AARCSTrafficPoliceDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isOnDuty = true;
  bool isConnected = true;

  bool hasEmergencyAlert = false;
  bool hasActiveEmergencyRequest = false;
  Map<String, dynamic>? currentEmergencyRequest;
  String? currentRequestId;
  String? currentAlertId;

  StreamSubscription<DatabaseEvent>? _requestSubscription;
  StreamSubscription<DatabaseEvent>? _trafficAlertSubscription;
  Timer? _alertPollingTimer;
  Timer? _notificationCheckTimer;

  String currentLocationText = "Fetching location...";
  String currentLandmark = "";
  Position? currentPosition;
  StreamSubscription<Position>? _locationSubscription;
  bool isLoadingLocation = true;

  final String _googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Track last shown notification to avoid duplicates
  String _lastShownAlertId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initialize notifications FIRST
    _initializeNotifications().then((_) {
      // Start listening and polling AFTER notifications are initialized
      _listenToEmergencyRequests();
      _listenToTrafficClearanceAlerts();
      _startPollingForAlerts();
      _startNotificationCheckTimer();
      _startLocationTracking();
    });
  }

  Future<void> _initializeNotifications() async {
    await LocalNotificationService.initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _requestSubscription?.cancel();
    _trafficAlertSubscription?.cancel();
    _alertPollingTimer?.cancel();
    _notificationCheckTimer?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  void _showAlertDialog(Map<String, dynamic> alertData, String alertId) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.traffic, color: Colors.orange),
            SizedBox(width: 10),
            Text('🚨 TRAFFIC CLEARANCE REQUEST'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ambulance: ${alertData['ambulanceId']}'),
            const SizedBox(height: 8),
            Text('Destination: ${alertData['destination']}'),
            const SizedBox(height: 8),
            Text('ETA: ${alertData['eta'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Distance: ${alertData['distance'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Priority: ${alertData['priorityLabel'] ?? 'MEDIUM'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _acknowledgeTrafficAlert(alertId);
            },
            child: const Text('ACKNOWLEDGE'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Just close dialog, don't acknowledge
              // Don't call _acknowledgeTrafficAlert here
              _handleTrafficAlertForResponse(alertData, alertId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('VIEW & RESPOND'),
          ),
        ],
      ),
    );
  }

  void _startPollingForAlerts() {
    _alertPollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final latestAlert = await FirebasePoliceService.getLatestActiveAlert();

        if (latestAlert != null) {
          final alertId = latestAlert['alertId'];
          final alertData = latestAlert['data'];

          // Check if this alert is already acknowledged
          if (alertData['acknowledged'] != true && alertData['status'] == 'active') {
            // Only show if it's a new alert
            if (alertId != _lastShownAlertId) {
              _lastShownAlertId = alertId;
              _handleBackgroundAlert(alertData, alertId);
            }
          }
        }
      } catch (e) {
        print('❌ Error polling for alerts: $e');
      }
    });
  }

  void _startNotificationCheckTimer() {
    _notificationCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkForMissedAlerts();
    });
  }

  Future<void> _checkForMissedAlerts() async {
    try {
      final latestAlert = await FirebasePoliceService.getLatestActiveAlert();

      if (latestAlert != null) {
        final alertId = latestAlert['alertId'];
        final alertData = latestAlert['data'];

        // If alert is active and not acknowledged, show notification
        if (alertData['acknowledged'] != true &&
            alertData['status'] == 'active' &&
            alertId != _lastShownAlertId) {
          await LocalNotificationService.showTrafficAlert(
            alertData['ambulanceId'] ?? 'Unknown',
            alertData['destination'] ?? 'Hospital',
            alertId,
          );

          _lastShownAlertId = alertId;
        }
      }
    } catch (e) {
      print('❌ Error checking for missed alerts: $e');
    }
  }

  void _handleBackgroundAlert(Map<String, dynamic> alertData, String alertId) {
    // Show system notification
    LocalNotificationService.showTrafficAlert(
      alertData['ambulanceId'] ?? 'Unknown',
      alertData['destination'] ?? 'Hospital',
      alertId,
    );

    // If app is in foreground, also show dialog
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAlertDialog(alertData, alertId);
      });
    }
  }

  void _listenToTrafficClearanceAlerts() {
    print("👂 Listening for traffic clearance alerts...");

    _trafficAlertSubscription =
        FirebasePoliceService.listenToTrafficClearanceAlerts().listen(
              (DatabaseEvent event) {
            if (event.snapshot.exists && mounted) {
              final alerts = event.snapshot.value as Map<dynamic, dynamic>;

              alerts.forEach((alertId, value) {
                final alertData = Map<String, dynamic>.from(value as Map);

                if (alertData['status'] == 'active' &&
                    alertData['acknowledged'] != true) {
                  print('📢 New traffic clearance alert: $alertId');
                  _handleTrafficAlert(alertData, alertId.toString());
                }
              });
            }
          },
          onError: (error) {
            print('❌ Error in traffic alert listener: $error');
          },
        );
  }

  void _handleTrafficAlert(Map<String, dynamic> alertData, String alertId) {
    // Update last shown alert ID
    _lastShownAlertId = alertId;

    // Show system notification
    LocalNotificationService.showTrafficAlert(
      alertData['ambulanceId'] ?? 'Unknown',
      alertData['destination'] ?? 'Hospital',
      alertId,
    );

    // If app is in foreground, show dialog and update UI
    if (mounted) {
      // Check if we already have this alert active
      if (currentAlertId == alertId && hasActiveEmergencyRequest) {
        return; // Don't show duplicate
      }

      _showAlertDialog(alertData, alertId);

      setState(() {
        hasEmergencyAlert = true;
        hasActiveEmergencyRequest = true;
        currentRequestId = alertId;
        currentAlertId = alertId; // Store the alert ID
        currentEmergencyRequest = {
          'ambulanceId': alertData['ambulanceId'] ?? 'Unknown',
          'destination': alertData['destination'] ?? 'Unknown',
          'eta': alertData['eta'] ?? 'N/A',
          'distance': alertData['distance'] ?? 'N/A',
          'priority': alertData['priority'] ?? 3,
          'priorityLabel': alertData['priorityLabel'] ?? 'MEDIUM',
          'currentLocation': alertData['currentLocation'] ?? 'Unknown',
          'status': 'active',
          'isTrafficAlert': true,
          'alertId': alertId,
          'requestId': alertData['requestId'],
        };
      });

      // Show in-app snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.traffic, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🚨 Ambulance ${alertData['ambulanceId']} needs traffic clearance!',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'ACKNOWLEDGE',
            textColor: Colors.white,
            onPressed: () {
              _acknowledgeTrafficAlert(alertId);
            },
          ),
        ),
      );
    }
  }

  void _handleTrafficAlertForResponse(
      Map<String, dynamic> alertData, String alertId) {
    if (!mounted) return;

    setState(() {
      currentAlertId = alertId;
      hasEmergencyAlert = true;
      hasActiveEmergencyRequest = true;
      currentEmergencyRequest = {
        'ambulanceId': alertData['ambulanceId'] ?? 'Unknown',
        'destination': alertData['destination'] ?? 'Unknown',
        'eta': alertData['eta'] ?? 'N/A',
        'distance': alertData['distance'] ?? 'N/A',
        'priority': alertData['priority'] ?? 3,
        'priorityLabel': alertData['priorityLabel'] ?? 'MEDIUM',
        'currentLocation': alertData['currentLocation'] ?? 'Unknown',
        'status': 'active',
        'isTrafficAlert': true,
        'alertId': alertId,
        'requestId': alertData['requestId'],
      };
    });

    // Navigate to response screen after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      _navigateToEmergencyResponse();
    });
  }

  Future<void> _acknowledgeTrafficAlert(String alertId) async {
    try {
      await FirebasePoliceService.acknowledgeTrafficAlert(alertId, 'TP-2024-156');
      print('✅ Traffic alert acknowledged: $alertId');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Traffic clearance request acknowledged'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Clear the alert from UI
        setState(() {
          hasEmergencyAlert = false;
          hasActiveEmergencyRequest = false;
          currentEmergencyRequest = null;
        });
      }
    } catch (e) {
      print('❌ Error acknowledging traffic alert: $e');
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          currentLocationText = "Location services disabled";
          isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            currentLocationText = "Location permission denied";
            isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          currentLocationText = "Location permission permanently denied";
          isLoadingLocation = false;
        });
        return;
      }

      Position initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _updateLocationText(initialPosition);

      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        _updateLocationText(position);
      });
    } catch (e) {
      print("Error getting location: $e");
      setState(() {
        currentLocationText = "Location unavailable";
        isLoadingLocation = false;
      });
    }
  }

  Future<void> _updateLocationText(Position position) async {
    try {
      setState(() {
        currentPosition = position;
      });

      final nearbyLandmark =
      await _getNearestLandmark(position.latitude, position.longitude);

      if (nearbyLandmark != null) {
        setState(() {
          currentLocationText = nearbyLandmark['name'];
          currentLandmark = nearbyLandmark['vicinity'];
          isLoadingLocation = false;
        });
      } else {
        await _fallbackReverseGeocode(position);
      }
    } catch (e) {
      print("Error updating location: $e");
      await _fallbackReverseGeocode(position);
    }
  }

  Future<Map<String, dynamic>?> _getNearestLandmark(
      double lat, double lng) async {
    try {
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?'
              'location=$lat,$lng&'
              'radius=100&'
              'type=point_of_interest|establishment|transit_station|bus_station|shopping_mall|store|restaurant|cafe|bank|atm|hospital|school|university|park|stadium|museum&'
              'rankby=distance&'
              'key=$_googleApiKey');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' &&
            data['results'] != null &&
            (data['results'] as List).isNotEmpty) {
          final results = data['results'] as List;
          for (var place in results) {
            final name = place['name'];
            final vicinity = place['vicinity'] ?? '';
            if (name != null &&
                !name.toString().toLowerCase().contains('unnamed') &&
                name.toString().length > 2) {
              return {
                'name': 'Near $name',
                'vicinity': vicinity,
              };
            }
          }
        }
      }
    } catch (e) {
      print("Error getting nearest landmark: $e");
    }
    return null;
  }

  Future<void> _fallbackReverseGeocode(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = '';

        if (place.street != null && place.street!.isNotEmpty) {
          address = place.street!;
        } else if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          address = place.subLocality!;
        } else if (place.locality != null && place.locality!.isNotEmpty) {
          address = place.locality!;
        } else {
          address =
          "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
        }

        List<String> landmarkParts = [];

        if (place.subLocality != null &&
            place.subLocality!.isNotEmpty &&
            place.subLocality != address) {
          landmarkParts.add(place.subLocality!);
        }

        if (place.locality != null &&
            place.locality!.isNotEmpty &&
            place.locality != address) {
          landmarkParts.add(place.locality!);
        }

        String landmark = landmarkParts.join(', ');

        setState(() {
          currentLocationText = address;
          currentLandmark = landmark;
          isLoadingLocation = false;
        });
      } else {
        setState(() {
          currentLocationText =
          "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
          currentLandmark = "Unknown Area";
          isLoadingLocation = false;
        });
      }
    } catch (e) {
      print("Error reverse geocoding: $e");
      setState(() {
        currentLocationText =
        "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
        currentLandmark = "Location service unavailable";
        isLoadingLocation = false;
      });
    }
  }

  Future<String> _convertCoordsToLandmark(String coordString) async {
    try {
      final regex = RegExp(r'Lat:\s*([-\d.]+),\s*Lng:\s*([-\d.]+)');
      final match = regex.firstMatch(coordString);

      if (match != null) {
        final lat = double.parse(match.group(1)!);
        final lng = double.parse(match.group(2)!);

        final landmark = await _getNearestLandmark(lat, lng);
        if (landmark != null) {
          return landmark['name'];
        }

        List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          if (place.street != null && place.street!.isNotEmpty) {
            return place.street!;
          } else if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            return place.subLocality!;
          } else if (place.locality != null && place.locality!.isNotEmpty) {
            return place.locality!;
          }
        }
      }
    } catch (e) {
      print("Error converting coords to landmark: $e");
    }
    return coordString;
  }

  void _listenToEmergencyRequests() {
    print("Traffic Police: Starting to listen for emergency requests...");

    _requestSubscription =
        FirebasePoliceService.listenToEmergencyRequests().listen((DatabaseEvent event) {
          if (event.snapshot.exists && mounted) {
            final requests =
            Map<String, dynamic>.from(event.snapshot.value as Map<dynamic, dynamic>);

            final pendingRequests = <String, Map<String, dynamic>>{};
            requests.forEach((key, value) {
              final requestData = Map<String, dynamic>.from(value);
              final status = requestData['status']?.toString() ?? '';
              if (status == 'pending') {
                pendingRequests[key.toString()] = requestData;
              }
            });

            if (pendingRequests.isNotEmpty) {
              var sortedEntries = pendingRequests.entries.toList()
                ..sort((a, b) {
                  final priorityA = a.value['priority'] ?? 3;
                  final priorityB = b.value['priority'] ?? 3;
                  if (priorityA != priorityB) {
                    return (priorityA as num).compareTo(priorityB as num);
                  }
                  final timestampA = a.value['timestamp'] ?? 0;
                  final timestampB = b.value['timestamp'] ?? 0;
                  return (timestampB as num).compareTo(timestampA as num);
                });

              final highestPriorityEntry = sortedEntries.first;
              final requestId = highestPriorityEntry.key;
              final requestData = highestPriorityEntry.value;

              if (currentRequestId == requestId && hasActiveEmergencyRequest) {
                return;
              }

              print("Processing HIGHEST PRIORITY request: $requestId");

              String currentLoc = requestData['currentLocation'] ?? 'Unknown';
              _convertCoordsToLandmark(currentLoc).then((landmark) {
                setState(() {
                  hasEmergencyAlert = true;
                  hasActiveEmergencyRequest = true;
                  currentRequestId = requestId;

                  final sourceCoords = requestData['sourceCoords'] is Map
                      ? Map<String, dynamic>.from(requestData['sourceCoords'])
                      : null;
                  final destCoords = requestData['destCoords'] is Map
                      ? Map<String, dynamic>.from(requestData['destCoords'])
                      : null;

                  currentEmergencyRequest = {
                    'ambulanceId': requestData['ambulanceId'] ?? 'Unknown',
                    'currentLocation': landmark,
                    'destination': requestData['destination'] ?? 'Unknown',
                    'eta': requestData['eta'] ?? 'Calculating...',
                    'distance': requestData['distance'] ?? 'N/A',
                    'priority': requestData['priority'] ?? 3,
                    'priorityLabel': requestData['priorityLabel'] ?? 'LOW',
                    'description': requestData['description'] ?? '',
                    'sourceCoords': sourceCoords,
                    'destCoords': destCoords,
                    'isTrafficAlert': false,
                  };
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${requestData['priorityLabel']} PRIORITY: ${requestData['ambulanceId']} → ${requestData['destination']}',
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 4),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              });
            } else {
              if (hasEmergencyAlert || hasActiveEmergencyRequest) {
                setState(() {
                  hasEmergencyAlert = false;
                  hasActiveEmergencyRequest = false;
                  currentEmergencyRequest = null;
                  currentRequestId = null;
                });
              }
            }
          } else {
            if (hasEmergencyAlert || hasActiveEmergencyRequest) {
              setState(() {
                hasEmergencyAlert = false;
                hasActiveEmergencyRequest = false;
                currentEmergencyRequest = null;
                currentRequestId = null;
              });
            }
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (hasEmergencyAlert) _buildEmergencyAlert(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(),
                _buildHistoryTab(),
                _buildProfileTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1976D2),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        color: Colors.white,
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AARCS Traffic Police',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: isConnected ? Colors.green : Colors.red, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(isConnected ? 'Connected' : 'Disconnected',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 8),
          child: Text(
            '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Dashboard'),
          Tab(text: 'History'),
          Tab(text: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildEmergencyAlert() {
    Color alertColor = Colors.red;
    String alertText = 'EMERGENCY ALERT: ambulance clearance request in your zone';

    if (currentEmergencyRequest != null &&
        currentEmergencyRequest!['isTrafficAlert'] == true) {
      alertColor = Colors.orange;
      alertText = '🚦 TRAFFIC CLEARANCE: Ambulance needs immediate clearance';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: alertColor,
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              alertText,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            color: Colors.white,
            iconSize: 20,
            onPressed: () {
              setState(() {
                hasEmergencyAlert = false;
              });
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBadgeCard(),
          const SizedBox(height: 20),
          hasActiveEmergencyRequest
              ? _buildEmergencyRequestCard()
              : _buildActiveRequestsCard(),
        ],
      ),
    );
  }

  Widget _buildBadgeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withAlpha((255 * 0.1).round()), // 10% opacity,
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.badge, color: Color(0xFF1976D2), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Badge: TP-2024-156',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    if (isLoadingLocation)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF1976D2))),
                      ),
                    if (isLoadingLocation) const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        currentLocationText,
                        style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (currentLandmark.isNotEmpty && !isLoadingLocation)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 18),
                    child: Text(
                      currentLandmark,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              Switch(
                value: isOnDuty,
                onChanged: (value) {
                  setState(() {
                    isOnDuty = value;
                  });
                },
                activeThumbColor: const Color(0xFF4CAF50),
                activeTrackColor: const Color(0xFF4CAF50).withOpacity(0.5),
              ),
              Text('ON DUTY',
                  style: TextStyle(
                      fontSize: 10,
                      color: isOnDuty ? const Color(0xFF4CAF50) : Colors.grey,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyRequestCard() {
    final isTrafficAlert = currentEmergencyRequest!['isTrafficAlert'] == true;
    final priority = EmergencyPriority.values[currentEmergencyRequest!['priority'] ?? 3];
    final priorityConfig = PriorityConfig.fromPriority(priority);
    final cardColor = isTrafficAlert ? Colors.orange : priorityConfig.backgroundColor;
    final borderColor = isTrafficAlert ? Colors.orange : priorityConfig.color;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    isTrafficAlert ? Icons.traffic : priorityConfig.icon,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isTrafficAlert ? 'TRAFFIC CLEARANCE REQUEST' : 'EMERGENCY REQUEST',
                    style: TextStyle(
                      color: borderColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isTrafficAlert ? 'TRAFFIC' : priorityConfig.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Ambulance ID: ${currentEmergencyRequest!['ambulanceId']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                if (isTrafficAlert)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.traffic, size: 16, color: Colors.orange.shade700),
                            const SizedBox(width: 6),
                            Text(
                              'Traffic Clearance Request:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ambulance requires immediate traffic clearance to reach destination quickly.',
                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                _buildDetailRow(
                  'Current',
                  currentEmergencyRequest!['currentLocation'] ?? 'Unknown',
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  'Destination',
                  currentEmergencyRequest!['destination'] ?? 'Unknown',
                ),
                const SizedBox(height: 12),
                _buildDetailRow('ETA', currentEmergencyRequest!['eta'] ?? '--'),
                const SizedBox(height: 12),
                _buildDetailRow('Distance', currentEmergencyRequest!['distance'] ?? '--'),
                const SizedBox(height: 20),
                if (isTrafficAlert)
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (currentEmergencyRequest!['alertId'] != null) {
                              _acknowledgeTrafficAlert(currentEmergencyRequest!['alertId']);
                            }
                            _navigateToEmergencyResponse();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'ACKNOWLEDGE & CLEAR',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _navigateToEmergencyResponse,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: borderColor,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      isTrafficAlert ? 'VIEW DETAILS' : 'CLEAR ROUTE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90, // Increased width slightly
          child: Text(
            '$label:',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8), // Reduced from 12
        Expanded( // Wrap in Expanded
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.black87,
            ),
            maxLines: 2, // Allow wrapping
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveRequestsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withOpacity(0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.shield, size: 48, color: Color(0xFF1976D2)),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Active Requests',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'All clear in your zone',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          Text(
            'Last updated: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return const HistoryScreen(
      ambulanceId: null,
      showAppBar: false,
    );
  }

  Widget _buildProfileTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: Color(0xFF1976D2),
            child: Icon(Icons.person, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'Inspector Raggul J',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          const Text(
            'Badge: TP-2024-156',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _navigateToEmergencyResponse() async {
    if (currentEmergencyRequest != null) {
      try {
        print("Navigating to Emergency Response Screen");

        final requestDataCopy = Map<String, dynamic>.from(currentEmergencyRequest!);

        // If it's a traffic alert, acknowledge it
        if (currentEmergencyRequest!['isTrafficAlert'] == true &&
            currentEmergencyRequest!['alertId'] != null) {
          await _acknowledgeTrafficAlert(currentEmergencyRequest!['alertId']);
        }

        // If it has a requestId from emergency_requests, accept it
        if (currentRequestId != null &&
            currentEmergencyRequest!['isTrafficAlert'] != true) {
          await FirebasePoliceService.acceptRequest(currentRequestId!);
          print("Request accepted in Firebase");
        }

        setState(() {
          hasActiveEmergencyRequest = false;
          hasEmergencyAlert = false;
        });

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmergencyResponseScreen(
                emergencyRequest: requestDataCopy,
              ),
            ),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Route clearance accepted'),
              backgroundColor: Color(0xFF4CAF50),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e, stackTrace) {
        print("Error navigating to emergency response: $e");
        print("Stack trace: $stackTrace");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to process request: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      print("No emergency request data available");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No emergency request data available'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}