import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/dashboard.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'config.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/route_navigation.dart';
import 'models/priority_model.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global notification listener reference
StreamSubscription<DatabaseEvent>? _notificationSubscription;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await dotenv.load(fileName: ".env");

  // Initialize local notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  final DarwinInitializationSettings initializationSettingsIOS =
  DarwinInitializationSettings();
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      if (response.payload != null) {
        final data = jsonDecode(response.payload!);
        // Navigate to route navigation screen
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => RouteNavigationScreen(
              ambulanceId: data['ambulanceId'],
              destination: data['destination'],
              destinationLat: data['destLat'],
              destinationLng: data['destLng'],
              onToggleTheme: () {}, // You can handle theme separately
              priority: EmergencyPriority.values[data['priority']],
              justification: data['description'],
            ),
          ),
        );
      }
    },
  );

  // Check for any pending notifications from when app was terminated
  await _handleBackgroundNotification();

  runApp(const MyApp());
}

// Global function to setup notification listener
void setupNotificationListener(String ambulanceId) {
  print('🎯 Setting up notification listener for ambulance: $ambulanceId');

  // Cancel any existing subscription
  _notificationSubscription?.cancel();

  final database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
  ).ref();

  // Listen for new notifications
  _notificationSubscription = database
      .child('ambulance_notifications')
      .orderByChild('timestamp')
      .limitToLast(5) // Get last 5 to catch any we might have missed
      .onChildAdded
      .listen((event) {
    print('📨 Firebase child added event triggered!');
    print('📨 Snapshot exists: ${event.snapshot.exists}');

    if (event.snapshot.exists) {
      final notification = Map<String, dynamic>.from(event.snapshot.value as Map);
      print('📨 Notification received: $notification');

      // Check if this notification is for this ambulance
      _checkAndShowNotification(notification, ambulanceId);
    } else {
      print('📨 Snapshot does not exist');
    }
  }, onError: (error) {
    print('❌ Listener error: $error');
  });

  print('✅ Notification listener set up for ambulance: $ambulanceId');

  // Also fetch existing unread notifications
  _fetchUnreadNotifications(ambulanceId);
}

// Add this new function to fetch any notifications that might have been missed
Future<void> _fetchUnreadNotifications(String ambulanceId) async {
  print('🔍 Fetching unread notifications for $ambulanceId');

  try {
    final database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
    ).ref();

    final snapshot = await database
        .child('ambulance_notifications')
        .orderByChild('ambulanceId')
        .equalTo(ambulanceId)
        .once();

    if (snapshot.snapshot.exists) {
      final notifications = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
      print('📚 Found ${notifications.length} notifications for $ambulanceId');

      notifications.forEach((key, value) {
        final notification = Map<String, dynamic>.from(value);
        if (notification['read'] == false) {
          print('📬 Unread notification found: $key');
          _checkAndShowNotification(notification, ambulanceId);
        }
      });
    } else {
      print('📭 No notifications found for $ambulanceId');
    }
  } catch (e) {
    print('❌ Error fetching unread notifications: $e');
  }
}

// Global function to check and show notification
Future<void> _checkAndShowNotification(Map<String, dynamic> notification, String currentAmbulanceId) async {
  try {
    print('🔍 Checking notification for ambulance: $currentAmbulanceId');
    print('🔍 Notification ambulanceId: ${notification['ambulanceId']}');
    print('🔍 Notification read status: ${notification['read']}');

    // Check if notification is for this ambulance and not read
    if (notification['ambulanceId'] == currentAmbulanceId) {

      if (notification['read'] == false) {
        print('✅ Notification matches and is unread! Showing notification...');

        // Mark as read in Firebase
        if (notification['notificationId'] != null) {
          try {
            final database = FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
            ).ref();

            await database
                .child('ambulance_notifications')
                .child(notification['notificationId'])
                .update({'read': true});
            print('✅ Marked notification as read');
          } catch (e) {
            print('❌ Error marking as read: $e');
          }
        }

        // Show local notification
        _showLocalNotification(notification);
      } else {
        print('ℹ️ Notification already read, skipping');
      }
    } else {
      print('ℹ️ Notification not for this ambulance (${notification['ambulanceId']} != $currentAmbulanceId)');
    }
  } catch (e) {
    debugPrint('Error checking notification: $e');
  }
}

// Global function to show local notification
Future<void> _showLocalNotification(Map<String, dynamic> notification) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
  AndroidNotificationDetails(
    'emergency_dispatches',
    'Emergency Dispatches',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    enableVibration: true,
    playSound: true,
  );

  const NotificationDetails platformChannelSpecifics =
  NotificationDetails(android: androidPlatformChannelSpecifics);

  final data = notification['data'] as Map<String, dynamic>? ?? {};

  String title = notification['title'] ?? '🚑 New Emergency';
  String body = notification['body'] ?? 'Emergency assigned to your ambulance';

  // Prepare payload for navigation
  Map<String, dynamic> payloadData = {
    'ambulanceId': data['ambulanceId'] ?? '',
    'destination': data['destination'] ?? 'Hospital',
    'destLat': data['destinationLat'] ?? 0.0,
    'destLng': data['destinationLng'] ?? 0.0,
    'priority': data['priority'] ?? 1,
    'description': data['description'] ?? '',
    'requestId': data['requestId'] ?? '',
  };

  String payload = jsonEncode(payloadData);

  await flutterLocalNotificationsPlugin.show(
    notification.hashCode,
    title,
    body,
    platformChannelSpecifics,
    payload: payload,
  );
}

// Handle background notification when app is launched from terminated state
Future<void> _handleBackgroundNotification() async {
  final prefs = await SharedPreferences.getInstance();
  final pendingNotification = prefs.getString('pending_notification');

  if (pendingNotification != null) {
    try {
      final data = jsonDecode(pendingNotification);
      // Clear pending notification
      await prefs.remove('pending_notification');

      // Store in shared preferences that we have a pending navigation
      await prefs.setString('pending_navigation', pendingNotification);
    } catch (e) {
      debugPrint('Error handling pending notification: $e');
    }
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    // Check for pending navigation after app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingNavigation();
    });
  }

  Future<void> _checkPendingNavigation() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingNav = prefs.getString('pending_navigation');

    if (pendingNav != null) {
      try {
        final data = jsonDecode(pendingNav);
        await prefs.remove('pending_navigation');

        // Navigate to route navigation screen
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => RouteNavigationScreen(
              ambulanceId: data['ambulanceId'],
              destination: data['destination'],
              destinationLat: data['destLat'],
              destinationLng: data['destLng'],
              onToggleTheme: _toggleTheme,
              priority: EmergencyPriority.values[data['priority']],
              justification: data['description'],
            ),
          ),
        );
      } catch (e) {
        debugPrint('Error navigating from pending: $e');
      }
    }
  }

  void _toggleTheme() {
    setState(() {
      _themeMode =
      _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'AARCS Ambulance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.red,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          bodySmall: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      themeMode: _themeMode,
      home: LoginScreen(
        onToggleTheme: _toggleTheme,
        isDark: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const LoginScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isButtonPressed = false;

  static const String _ambulanceIdKey = 'ambulance_id';
  static const String _passwordKey = 'password';
  static const String _rememberMeKey = 'remember_me';

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRememberMe = prefs.getBool(_rememberMeKey) ?? false;

      if (savedRememberMe) {
        final savedId = prefs.getString(_ambulanceIdKey) ?? '';
        final savedPassword = prefs.getString(_passwordKey) ?? '';

        setState(() {
          _idController.text = savedId;
          _passwordController.text = savedPassword;
          _rememberMe = savedRememberMe;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved credentials: $e');
    }
  }

  Future<void> _saveCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_rememberMe) {
        await prefs.setString(_ambulanceIdKey, _idController.text.trim().toUpperCase());
        await prefs.setString(_passwordKey, _passwordController.text.trim());
        await prefs.setBool(_rememberMeKey, true);
      } else {
        await prefs.remove(_ambulanceIdKey);
        await prefs.remove(_passwordKey);
        await prefs.setBool(_rememberMeKey, false);
      }
    } catch (e) {
      debugPrint('Error saving credentials: $e');
    }
  }

  Future<void> _clearSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_ambulanceIdKey);
      await prefs.remove(_passwordKey);
      await prefs.remove(_rememberMeKey);
    } catch (e) {
      debugPrint('Error clearing credentials: $e');
    }
  }

  void _login() async {
    String id = _idController.text.trim().toUpperCase();
    String password = _passwordController.text.trim();

    if (id.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter Ambulance ID and Password")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.red),
      ),
    );

    try {
      final backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:3000';

      print('🔍 Connecting to: $backendUrl');
      print('🚑 Authenticating: $id');

      final response = await http.post(
        Uri.parse(Config.ambulanceAuthEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'ambulanceId': id,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (mounted) Navigator.of(context).pop();

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          final String customToken = responseData['token'];
          final String ambulanceId = responseData['ambulanceId'];

          print('✅ Token received, signing in to Firebase...');

          await FirebaseAuth.instance.signInWithCustomToken(customToken);

          await _saveCredentials(); // This already saves ambulance ID

          // Also store in Firebase for notification targeting
          final database = FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
          ).ref();

          await database.child('active_ambulances').child(ambulanceId).set({
            'lastSeen': ServerValue.timestamp, // This is correct
            'status': 'active'
          });

          // Set up notification listener for this ambulance
          setupNotificationListener(ambulanceId);

          print('✅ Login successful!');

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DashboardScreen(
                  ambulanceId: ambulanceId,
                  onToggleTheme: widget.onToggleTheme,
                ),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(responseData['message'] ?? 'Invalid credentials'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Invalid Ambulance ID or Password"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } on http.ClientException catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();

      print('❌ Connection Error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cannot connect to server. Check backend is running."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();

      print('❌ Error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(
                      widget.isDark ? Icons.wb_sunny : Icons.nights_stay,
                      color: Colors.red,
                    ),
                    onPressed: widget.onToggleTheme,
                  ),
                ),
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.medical_services,
                      color: Colors.white, size: 40),
                ),
                const SizedBox(height: 16),
                const Text(
                  "AARCS Ambulance",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red),
                ),
                const Text(
                  "Emergency Medical Services",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _idController,
                  decoration: const InputDecoration(
                    labelText: "Ambulance ID",
                    prefixIcon: Icon(Icons.local_shipping_outlined,
                        color: Colors.red),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon:
                    const Icon(Icons.lock_outline, color: Colors.red),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.red,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      activeColor: Colors.red,
                      onChanged: (value) {
                        setState(() {
                          _rememberMe = value ?? false;
                        });
                        if (!_rememberMe) {
                          _clearSavedCredentials();
                        }
                      },
                    ),
                    const Text("Remember Me"),
                  ],
                ),
                const SizedBox(height: 20),
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
                      _login();
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 50,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _isButtonPressed
                          ? Colors.red.shade700
                          : Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      "Login",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    // Cancel notification subscription when logging out
    _notificationSubscription?.cancel();
    super.dispose();
  }
}