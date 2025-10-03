import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';
import 'emergency_response_screen.dart';

class AARCSTrafficPoliceDashboard extends StatefulWidget {
  @override
  _AARCSTrafficPoliceDashboardState createState() => _AARCSTrafficPoliceDashboardState();
}

class _AARCSTrafficPoliceDashboardState extends State<AARCSTrafficPoliceDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isOnDuty = true;
  bool isConnected = true;
  int selectedTabIndex = 0;

  // Emergency request state
  bool hasEmergencyAlert = false;
  bool hasActiveEmergencyRequest = false;
  Map<String, dynamic>? currentEmergencyRequest;

  // Mock ambulance data with COORDINATES
  final List<Map<String, dynamic>> mockAmbulanceRequests = [
    {
      'ambulanceId': 'AMB-2024-001',
      'currentLocation': '21st cross street, Padmavathy Nagar Main Rd, Padmavathy Nagar, Madambakkam, Chennai, Tamil Nadu 600126',
      'destination': 'Bharath Hospital',
      'eta': '5 mins',
      // ✅ ADD COORDINATE DATA FOR NAVIGATION
      'sourceCoords': {
        'lat': 12.8502, // Madambakkam coordinates
        'lng': 80.0982,
      },
      'destCoords': {
        'lat': 12.9716, // Chennai General Hospital coordinates  
        'lng': 80.2397,
      },
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        selectedTabIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Emergency Alert Banner
          if (hasEmergencyAlert) _buildEmergencyAlert(),
          // Tab Content
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _simulateEmergencyRequest();
        },
        backgroundColor: const Color(0xFF1976D2),
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1976D2),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AARCS Traffic Police',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isConnected ? 'Connected' : 'Disconnected',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 16, top: 8),
          child: Text(
            '14:39',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.red,
      child: Row(
        children: [
          const Icon(
            Icons.warning,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'EMERGENCY ALERT\nNew ambulance clearance request in your zone',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
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
          const SizedBox(height: 20),
          _buildStatsCards(),
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
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
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
            child: const Icon(
              Icons.badge,
              color: Color(0xFF1976D2),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Badge: TP-2024-156',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Zone: Zone-A (MG Road)',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
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
                activeColor: const Color(0xFF4CAF50),
              ),
              Text(
                'ON DUTY',
                style: TextStyle(
                  fontSize: 10,
                  color: isOnDuty ? const Color(0xFF4CAF50) : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyRequestCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red, width: 2),
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
          // Emergency Request Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
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
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.medical_services,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'EMERGENCY REQUEST',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'URGENT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Request Details
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
                _buildDetailRow('Current\nLocation:', currentEmergencyRequest!['currentLocation']),
                const SizedBox(height: 12),
                _buildDetailRow('Destination:', currentEmergencyRequest!['destination']),
                const SizedBox(height: 12),
                _buildDetailRow('ETA:', currentEmergencyRequest!['eta']),
                const SizedBox(height: 20),
                // ✅ UPDATED CLEAR ROUTE BUTTON WITH NAVIGATION
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _navigateToEmergencyResponse();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'CLEAR ROUTE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.black87,
            ),
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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield,
              size: 48,
              color: Color(0xFF1976D2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Active Requests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All clear in your zone',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Last updated: 14:39',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.check_circle_outline,
            value: '12',
            label: "Today's Clearances",
            color: const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            icon: Icons.timer_outlined,
            value: '2.3 min',
            label: 'Avg Response',
            color: const Color(0xFFFF9800),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'History',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your recent activities will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircleAvatar(
            radius: 40,
            backgroundColor: Color(0xFF1976D2),
            child: Icon(
              Icons.person,
              size: 40,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Profile',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Manage your profile settings',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  void _simulateEmergencyRequest() {
    // Simulate receiving an ambulance clearance request
    final random = Random();
    final randomRequest = mockAmbulanceRequests[random.nextInt(mockAmbulanceRequests.length)];

    setState(() {
      hasEmergencyAlert = true;
      hasActiveEmergencyRequest = true;
      currentEmergencyRequest = randomRequest;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Emergency request received!'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ✅ NEW METHOD - NAVIGATION TO EMERGENCY RESPONSE SCREEN
  void _navigateToEmergencyResponse() {
    if (currentEmergencyRequest != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmergencyResponseScreen(
            emergencyRequest: currentEmergencyRequest!,
          ),
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Navigating to emergency response screen...'),
          backgroundColor: Color(0xFF4CAF50),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ✅ KEPT FOR BACKWARD COMPATIBILITY
  void _clearRoute() {
    _navigateToEmergencyResponse();
  }
}
