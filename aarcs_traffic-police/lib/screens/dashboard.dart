// lib/screens/dashboard.dart (Traffic Police)

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';
import 'dart:async';
import 'emergency_response_screen.dart';
import 'history_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/priority_model.dart'; // ✅ ADDED: Import priority model

// Firebase Police Service for real-time data
class FirebasePoliceService {
  static final DatabaseReference _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
  ).ref();

  static Stream<DatabaseEvent> listenToEmergencyRequests() {
    return _database
        .child('emergency_requests')
        .orderByChild('timestamp')
        .limitToLast(5)
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        selectedTabIndex = _tabController.index;
      });
    });

    _listenToEmergencyRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _requestSubscription?.cancel();
    super.dispose();
  }

  // ✅ UPDATED: Filter to show only highest priority ambulance
  void _listenToEmergencyRequests() {
    print('🚓 Traffic Police: Starting to listen for emergency requests...');

    _requestSubscription = FirebasePoliceService.listenToEmergencyRequests()
        .listen((DatabaseEvent event) {
      print('🚓 Traffic Police: Firebase event received!');
      print('🚓 Data exists: ${event.snapshot.exists}');
      print('🚓 Event type: ${event.type}');

      if (event.snapshot.exists && mounted) {
        print('🚓 Raw data: ${event.snapshot.value}');

        final requests = Map<String, dynamic>.from(
            event.snapshot.value as Map<dynamic, dynamic>);

        print('🚓 Number of requests: ${requests.length}');

        final pendingRequests = <String, Map<String, dynamic>>{};

        requests.forEach((key, value) {
          final requestData = Map<String, dynamic>.from(value);
          final status = requestData['status']?.toString() ?? '';

          print('🚓 Request $key - Status: $status');

          if (status == 'pending') {
            pendingRequests[key.toString()] = requestData;
          }
        });

        print('🚓 Filtered pending requests: ${pendingRequests.length}');

        if (pendingRequests.isNotEmpty) {
          // ✅ CRITICAL CHANGE: Sort by priority first (lower index = higher priority)
          // Then by timestamp for same priority
          var sortedEntries = pendingRequests.entries.toList()
            ..sort((a, b) {
              // Get priority (default to 3 = low if missing)
              final priorityA = a.value['priority'] ?? 3;
              final priorityB = b.value['priority'] ?? 3;

              // Lower priority index = higher priority (0=critical is highest)
              if (priorityA != priorityB) {
                return (priorityA as num).compareTo(priorityB as num);
              }

              // If same priority, sort by timestamp (newer first)
              final timestampA = a.value['timestamp'] ?? 0;
              final timestampB = b.value['timestamp'] ?? 0;
              return (timestampB as num).compareTo(timestampA as num);
            });

          // ✅ ONLY show the highest priority request (first in sorted list)
          final highestPriorityEntry = sortedEntries.first;
          final requestId = highestPriorityEntry.key;
          final requestData = highestPriorityEntry.value;

          // Check if this is already being displayed
          if (currentRequestId == requestId && hasActiveEmergencyRequest) {
            print('🚓 Request $requestId already being displayed, skipping...');
            return;
          }

          print('🚓 Processing HIGHEST PRIORITY request: $requestId');
          print('🚓 Priority: ${requestData['priority']} (${requestData['priorityLabel']})');
          print('🚓 Destination: ${requestData['destination']}');

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
              'priority': requestData['priority'] ?? 3, // ✅ ADDED: Store priority
              'priorityLabel': requestData['priorityLabel'] ?? 'LOW', // ✅ ADDED: Store priority label
              'sourceCoords': sourceCoords,
              'destCoords': destCoords,
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
                        '🚨 ${requestData['priorityLabel']} PRIORITY: ${requestData['ambulanceId']} → ${requestData['destination']}'),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          print('🚓 No pending requests found, clearing alerts...');
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
        print('🚓 No emergency requests data exists');
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

  // ✅ UPDATED: Show priority in emergency request card
  Widget _buildEmergencyRequestCard() {
    // ✅ ADDED: Get priority configuration
    final priority = EmergencyPriority.values[currentEmergencyRequest!['priority'] ?? 3];
    final priorityConfig = PriorityConfig.fromPriority(priority);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: priorityConfig.color, width: 2), // ✅ CHANGED: Use priority color
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
              color: priorityConfig.backgroundColor, // ✅ CHANGED: Use priority color
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
                    color: priorityConfig.color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    priorityConfig.icon, // ✅ CHANGED: Use priority icon
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'EMERGENCY REQUEST',
                  style: TextStyle(
                    color: priorityConfig.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                // ✅ ADDED: Priority badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityConfig.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    priorityConfig.label,
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
                _buildDetailRow('Current\nLocation:',
                    currentEmergencyRequest!['currentLocation']),
                const SizedBox(height: 12),
                _buildDetailRow('Destination:',
                    currentEmergencyRequest!['destination'] ?? 'Unknown'),
                const SizedBox(height: 12),
                _buildDetailRow(
                    'ETA:', currentEmergencyRequest!['eta'] ?? '--'),
                const SizedBox(height: 12),
                _buildDetailRow(
                    'Distance:', currentEmergencyRequest!['distance'] ?? '--'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _navigateToEmergencyResponse();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: priorityConfig.color, // ✅ CHANGED: Use priority color
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
        print('🚓 Navigating to Emergency Response Screen');
        print('🚓 Request ID: $currentRequestId');
        print('🚓 Emergency Request data: $currentEmergencyRequest');

        final requestDataCopy = Map<String, dynamic>.from(currentEmergencyRequest!);
        final requestIdCopy = currentRequestId!;

        setState(() {
          hasActiveEmergencyRequest = false;
          hasEmergencyAlert = false;
          currentEmergencyRequest = null;
          currentRequestId = null;
        });

        await FirebasePoliceService.acceptRequest(requestIdCopy);
        print('✅ Request accepted in Firebase');

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
              content: Text('✅ Route clearance accepted'),
              backgroundColor: Color(0xFF4CAF50),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e, stackTrace) {
        print('❌ Error navigating to emergency response: $e');
        print('Stack trace: $stackTrace');
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
      print('⚠️ No emergency request data available');
      print('currentEmergencyRequest: $currentEmergencyRequest');
      print('currentRequestId: $currentRequestId');
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
