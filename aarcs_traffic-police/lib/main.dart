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
import 'screens/emergency_response_screen.dart';
import 'models/priority_model.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await dotenv.load(fileName: ".env");

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
        // Navigate to dashboard with the alert data
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => AARCSTrafficPoliceDashboard(
              initialAlertPayload: data,
            ),
          ),
        );
      }
    },
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Traffic Police System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
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

  static const String _policeIdKey = 'police_id';
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
        final savedId = prefs.getString(_policeIdKey) ?? '';
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
        await prefs.setString(_policeIdKey, _idController.text.trim().toUpperCase());
        await prefs.setString(_passwordKey, _passwordController.text.trim());
        await prefs.setBool(_rememberMeKey, true);
      } else {
        await prefs.remove(_policeIdKey);
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
      await prefs.remove(_policeIdKey);
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
        const SnackBar(content: Text("Please enter Police ID and Password")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.blue),
      ),
    );

    try {
      final backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:3000';

      print('🔍 Connecting to: $backendUrl/authenticate/police');
      print('🚔 Authenticating: $id');

      final response = await http.post(
        Uri.parse(Config.policeAuthEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'policeId': id,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (mounted) Navigator.of(context).pop();

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          final String customToken = responseData['token'];
          final String policeId = responseData['userId'];

          print('✅ Token received, signing in to Firebase...');

          await FirebaseAuth.instance.signInWithCustomToken(customToken);

          await _saveCredentials();

          print('✅ Login successful!');

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const AARCSTrafficPoliceDashboard(),
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
              content: Text("Invalid Police ID or Password"),
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
                      color: Colors.blue,
                    ),
                    onPressed: widget.onToggleTheme,
                  ),
                ),
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.local_police,
                      color: Colors.white, size: 40),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Traffic Police System",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue),
                ),
                const Text(
                  "Law Enforcement Services",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _idController,
                  decoration: const InputDecoration(
                    labelText: "Police ID",
                    prefixIcon: Icon(Icons.badge, color: Colors.blue),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon:
                    const Icon(Icons.lock_outline, color: Colors.blue),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.blue,
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
                      activeColor: Colors.blue,
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
                          ? Colors.blue.shade700
                          : Colors.blue,
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
    super.dispose();
  }
}