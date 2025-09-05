import 'package:flutter/material.dart';

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
  final List<String> recentDestinations = [];

  @override
  Widget build(BuildContext context) {
    // ✅ check theme directly
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🚑 ID + 🌞/🌙 toggle
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
                    // Add trip logic here
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

              const Text(
                "Nearby destinations",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: recentDestinations.isEmpty
                    ? const Center(
                  child: Text(
                    "No destinations yet",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
                    : ListView.builder(
                  itemCount: recentDestinations.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.location_on_outlined,
                          color: Colors.red),
                      title: Text(recentDestinations[index]),
                      trailing: const Text(
                        "Select",
                        style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: "New Trip"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
        ],
      ),
    );
  }
}
