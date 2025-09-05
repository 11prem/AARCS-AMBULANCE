import 'package:flutter/material.dart';
import 'screens/dashboard.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light; // default is light

  void _toggleTheme() {
    setState(() {
      _themeMode =
      _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AARCS Ambulance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.red,
      ),
      themeMode: _themeMode,
      home: LoginScreen(
        onToggleTheme: _toggleTheme,
        isDark: _themeMode == ThemeMode.dark, // ✅ pass theme state
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

  final Map<String, String> validCredentials = {
    "AMB001": "emergency123",
    "AMB002": "emergency234",
    "AMB003": "emergency456",
  };

  void _login() {
    String id = _idController.text.trim();
    String password = _passwordController.text.trim();

    if (validCredentials.containsKey(id) &&
        validCredentials[id] == password) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(
            ambulanceId: id,
            onToggleTheme: widget.onToggleTheme,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid Ambulance ID or Password")),
      );
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
                // 🌞/🌙 Theme toggle
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

                // 🚑 Logo
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

                // Ambulance ID
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

                // Password
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
}
