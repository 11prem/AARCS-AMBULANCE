import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';
import 'dart:async';
import 'emergency_response_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

// Firebase Police Service for real-time data
class FirebasePoliceService {
  static final DatabaseReference _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
  ).ref();

  static Stream<DatabaseEvent> listenToEmergencyRequests() {
    return _database
        .child('emergency_requests')
        .orderByChild('timestamp') // ✅ Order by timestamp instead of status
        .limitToLast(5) // ✅ Only get the 5 most recent requests
        .onValue;
  }

  static Future<void> acceptRequest(String requestId) async {
    await _database.child('emergency_requests').child(requestId).update({
      'status': 'accepted',
      'accepted_at': ServerValue.timestamp,
    });
  }
}



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
  String? currentRequestId;

  // Firebase subscription
  StreamSubscription<DatabaseEvent>? _requestSubscription;

  // Statistics
  int todaysClearances = 12;
  String avgResponseTime = '2.3 min';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        selectedTabIndex = _tabController.index;
      });
    });

    // Start listening for Firebase emergency requests
    _listenToEmergencyRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _requestSubscription?.cancel();
    super.dispose();
  }

  void _listenToEmergencyRequests() {
    print('🚓 Traffic Police: Starting to listen for emergency requests...'); // DEBUG
    _requestSubscription = FirebasePoliceService.listenToEmergencyRequests()
        .listen((DatabaseEvent event) {
      print('🚓 Traffic Police: Firebase event received!'); // DEBUG
      print('🚓 Data exists: ${event.snapshot.exists}'); // DEBUG
      print('🚓 Event type: ${event.type}'); // DEBUG

      if (event.snapshot.exists && mounted) {
        print('🚓 Raw data: ${event.snapshot.value}'); // DEBUG
        final requests = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        print('🚓 Number of requests: ${requests.length}'); // DEBUG

        // ✅ FIXED: Filter out non-pending requests
        final pendingRequests = <String, Map<String, dynamic>>{};

        requests.forEach((key, value) {
          final requestData = Map<String, dynamic>.from(value);
          final status = requestData['status']?.toString() ?? '';

          print('🚓 Request $key - Status: $status'); // DEBUG

          // Only include truly pending requests
          if (status == 'pending') {
            pendingRequests[key.toString()] = requestData;
          }
        });

        print('🚓 Filtered pending requests: ${pendingRequests.length}'); // DEBUG

        if (pendingRequests.isNotEmpty) {
          // Get the LATEST request by timestamp
          var sortedEntries = pendingRequests.entries.toList()
            ..sort((a, b) {
              final timestampA = a.value['timestamp'] ?? 0;
              final timestampB = b.value['timestamp'] ?? 0;
              return (timestampB as num).compareTo(timestampA as num);
            });

          final latestEntry = sortedEntries.first;
          final requestId = latestEntry.key;
          final requestData = latestEntry.value;

          // Don't show alert if this request was already processed
          if (currentRequestId == requestId && hasActiveEmergencyRequest) {
            print('🚓 Request $requestId already being displayed, skipping...'); // DEBUG
            return;
          }

          print('🚓 Processing NEW request: $requestId'); // DEBUG
          print('🚓 Destination: ${requestData['destination']}'); // DEBUG

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
              'currentLocation': requestData['currentLocation'] ?? 'Unknown',
              'destination': requestData['destination'] ?? 'Unknown',
              'eta': requestData['eta'] ?? 'Calculating...',
              'distance': requestData['distance'] ?? 'N/A',
              'sourceCoords': sourceCoords,
              'destCoords': destCoords,
            };
          });

          // Show notification
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        '🚨 Emergency: ${requestData['ambulanceId']} → ${requestData['destination']}'
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          // No pending requests, clear the emergency alert
          print('🚓 No pending requests found, clearing alerts...'); // DEBUG
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
        // No data exists, clear any existing alerts
        print('🚓 No emergency requests data exists'); // DEBUG
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
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 8),
          child: Text(
            '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
            style: const TextStyle(
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

                _buildDetailRow('Current\\nLocation:', currentEmergencyRequest!['currentLocation']),
                const SizedBox(height: 12),

                // ✅ FIXED: Display correct destination from Firebase
                _buildDetailRow('Destination:', currentEmergencyRequest!['destination'] ?? 'Unknown'),
                const SizedBox(height: 12),

                _buildDetailRow('ETA:', currentEmergencyRequest!['eta'] ?? '--'),
                const SizedBox(height: 12),

                _buildDetailRow('Distance:', currentEmergencyRequest!['distance'] ?? '--'),
                const SizedBox(height: 20),

                // Clear Route Button
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
            'Last updated: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
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
            value: todaysClearances.toString(),
            label: "Today's Clearances",
            color: const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            icon: Icons.timer_outlined,
            value: avgResponseTime,
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
            'Inspector Raggul J',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Badge: TP-2024-156',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToEmergencyResponse() async {
    if (currentEmergencyRequest != null && currentRequestId != null) {
      try {
        // Accept the request
        await FirebasePoliceService.acceptRequest(currentRequestId!);

        // Navigate to emergency response screen
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
            content: Text('✅ Route clearance accepted'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 2),
          ),
        );

        // Update statistics
        setState(() {
          todaysClearances++;
          hasActiveEmergencyRequest = false;
          hasEmergencyAlert = false;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
