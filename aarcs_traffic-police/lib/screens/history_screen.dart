import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  final bool showAppBar;

  const HistoryScreen({Key? key, this.showAppBar = true}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseReference _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://aarcs-2f28b-default-rtdb.asia-southeast1.firebasedatabase.app',
  ).ref();

  List<Map<String, dynamic>> _historyItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get ALL emergency requests
      final snapshot = await _database
          .child('emergency_requests')
          .get();

      if (snapshot.exists) {
        // 👇 ADD THE DEBUG CODE HERE 👇
        print('📊 History: Snapshot exists');
        print('📊 Raw data: ${snapshot.value}');
        final requests = Map<String, dynamic>.from(snapshot.value as Map);
        print('📊 Total requests: ${requests.length}');
        // 👆 END OF DEBUG CODE 👆

        List<Map<String, dynamic>> historyList = [];

        requests.forEach((key, value) {
          final requestData = Map<String, dynamic>.from(value);
          final status = requestData['status']?.toString() ?? '';

          // Filter for accepted/completed/cancelled
          if (status == 'accepted' || status == 'completed' || status == 'cancelled') {
            historyList.add({
              'requestId': key,
              'ambulanceId': requestData['ambulanceId'] ?? 'Unknown',
              'currentLocation': requestData['currentLocation'] ?? 'Unknown',
              'destination': requestData['destination'] ?? 'Unknown',
              'status': status,
              'timestamp': requestData['timestamp'] ?? 0,
              'accepted_at': requestData['accepted_at'] ?? 0,
              'completed_at': requestData['completed_at'] ?? 0,
              'eta': requestData['eta'] ?? 'N/A',
              'distance': requestData['distance'] ?? 'N/A',
            });
          }
        });

        // Sort by timestamp (newest first)
        historyList.sort((a, b) {
          final aTime = a['accepted_at'] ?? a['timestamp'] ?? 0;
          final bTime = b['accepted_at'] ?? b['timestamp'] ?? 0;
          return (bTime as num).compareTo(aTime as num);
        });

        setState(() {
          _historyItems = historyList;
          _isLoading = false;
        });
      } else {
        // 👇 ALSO ADD DEBUG HERE 👇
        print('📊 History: No snapshot found');
        // 👆 END OF DEBUG CODE 👆

        setState(() {
          _historyItems = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading history: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null || timestamp == 0) return 'N/A';
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
      return DateFormat('MMM dd, yyyy HH:mm').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _calculateDuration(dynamic acceptedAt, dynamic completedAt) {
    if (acceptedAt == null || acceptedAt == 0 || completedAt == null || completedAt == 0) {
      return 'N/A';
    }

    try {
      final accepted = DateTime.fromMillisecondsSinceEpoch(acceptedAt as int);
      final completed = DateTime.fromMillisecondsSinceEpoch(completedAt as int);
      final duration = completed.difference(accepted);

      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;

      if (hours > 0) {
        return '${hours}h ${minutes}m';
      } else {
        return '${minutes}m';
      }
    } catch (e) {
      return 'N/A';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'accepted':
        return Colors.blue;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'accepted':
        return Icons.local_shipping;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    // If showAppBar is false, return just the body without Scaffold
    if (!widget.showAppBar) {
      return _buildBody();
    }

    // Otherwise, return full Scaffold with AppBar
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Clearance History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
        ),
      );
    }

    if (_historyItems.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _historyItems.length,
        itemBuilder: (context, index) {
          return _buildHistoryCard(_historyItems[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No History Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Accepted requests will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? 'unknown';
    final statusColor = _getStatusColor(status);
    final duration = _calculateDuration(item['accepted_at'], item['completed_at']);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getStatusIcon(status),
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['ambulanceId'] ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Request ID: ${item['requestId'].substring(0, 8)}...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Details Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Locations
                _buildDetailRow(
                  Icons.location_on,
                  'From',
                  item['currentLocation'] ?? 'Unknown',
                  Colors.blue,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.local_hospital,
                  'To',
                  item['destination'] ?? 'Unknown',
                  Colors.red,
                ),
                const Divider(height: 24),
                // Timestamps
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        'Accepted',
                        _formatTimestamp(item['accepted_at']),
                        Icons.check_circle_outline,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoChip(
                        'Completed',
                        _formatTimestamp(item['completed_at']),
                        Icons.flag,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Duration and Distance
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        'Duration',
                        duration,
                        Icons.timer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoChip(
                        'Distance',
                        item['distance'] ?? 'N/A',
                        Icons.route,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
