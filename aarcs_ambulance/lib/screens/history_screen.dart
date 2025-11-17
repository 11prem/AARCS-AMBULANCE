import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ ADDED: For clipboard functionality
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

class HistoryScreen extends StatefulWidget {
  final bool showAppBar;
  final String? ambulanceId;

  const HistoryScreen({
    Key? key,
    this.showAppBar = true,
    this.ambulanceId,
  }) : super(key: key);

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

      print('🔍 Querying history for ambulance: ${widget.ambulanceId}');

      final snapshot = await _database
          .child('emergency_requests')
          .get();

      print('📊 Snapshot exists: ${snapshot.exists}');
      print('📊 Raw data: ${snapshot.value}');

      if (snapshot.exists) {
        final requests = Map<String, dynamic>.from(snapshot.value as Map);
        print('📦 Total requests in database: ${requests.length}');

        List<Map<String, dynamic>> historyList = [];

        requests.forEach((key, value) {
          final requestData = Map<String, dynamic>.from(value);
          final status = requestData['status']?.toString() ?? '';
          final reqAmbulanceId = requestData['ambulanceId']?.toString() ?? '';

          print('🔍 Checking request: $key');
          print('   - Ambulance ID: $reqAmbulanceId');
          print('   - Status: $status');
          print('   - Match: ${reqAmbulanceId == widget.ambulanceId}');

          if (reqAmbulanceId == widget.ambulanceId &&
              (status == 'accepted' || status == 'completed' || status == 'cancelled')) {
            final sourceCoords = requestData['sourceCoords'];
            final destCoords = requestData['destCoords'];

            historyList.add({
              'requestId': key,
              'ambulanceId': requestData['ambulanceId'] ?? 'Unknown',
              'currentLocation': requestData['currentLocation'] ?? 'Unknown', // ✅ This is already landmark from Firebase
              'destination': requestData['destination'] ?? 'Unknown Hospital',
              'status': status,
              'timestamp': requestData['timestamp'] ?? 0,
              'accepted_at': requestData['accepted_at'] ?? 0,
              'completed_at': requestData['completed_at'] ?? 0,
              'eta': requestData['eta'] ?? 'N/A',
              'distance': requestData['distance'] ?? 'N/A',
              'sourceLat': sourceCoords != null ? sourceCoords['lat'] : 0.0,
              'sourceLng': sourceCoords != null ? sourceCoords['lng'] : 0.0,
              'destLat': destCoords != null ? destCoords['lat'] : 0.0,
              'destLng': destCoords != null ? destCoords['lng'] : 0.0,
              'trafficClearanceRequested': status == 'accepted' || status == 'completed',
            });
          }
        });

        print('📋 Total matching history items: ${historyList.length}');

        historyList.sort((a, b) {
          final aTime = a['timestamp'] ?? 0;
          final bTime = b['timestamp'] ?? 0;
          return (bTime as num).compareTo(aTime as num);
        });

        setState(() {
          _historyItems = historyList;
          _isLoading = false;
        });
      } else {
        print('📊 History: No snapshot found');
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
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = months[date.month - 1];
      final day = date.day.toString().padLeft(2, '0');
      final year = date.year;
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$month $day, $year $hour:$minute';
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _calculateDuration(dynamic startTime, dynamic completedTime) {
    if (startTime == null || startTime == 0 || completedTime == null || completedTime == 0) {
      return 'N/A';
    }

    try {
      final start = DateTime.fromMillisecondsSinceEpoch(startTime as int);
      final completed = DateTime.fromMillisecondsSinceEpoch(completedTime as int);
      final duration = completed.difference(start);
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

  // ✅ NEW: Copy to clipboard function
  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showAppBar) {
      return _buildBody();
    }

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
          'Trip History',
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
            'No Trip History Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Completed trips will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? 'unknown';
    final statusColor = _getStatusColor(status);
    final duration = _calculateDuration(item['timestamp'], item['completed_at']);
    final trafficRequested = item['trafficClearanceRequested'] ?? false;
    final tripId = item['requestId'] ?? 'Unknown';

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
                        item['destination'] ?? 'Unknown Hospital',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // ✅ UPDATED: Full Trip ID with copy functionality
                      GestureDetector(
                        onTap: () => _copyToClipboard(tripId, 'Trip ID'),
                        child: Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                'Trip ID: $tripId',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white70
                                      : Colors.grey[600],
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.copy,
                              size: 14,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white70
                                  : Colors.grey[600],
                            ),
                          ],
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
                // ✅ UPDATED: Starting Location with landmark only
                _buildDetailRow(
                  Icons.my_location,
                  'Starting Location',
                  item['currentLocation'] ?? 'Unknown', // Shows landmark directly
                  Colors.blue,
                ),
                const SizedBox(height: 12),

                // Hospital Destination
                _buildDetailRow(
                  Icons.local_hospital,
                  'Hospital Destination',
                  item['destination'] ?? 'Unknown',
                  Colors.red,
                ),

                const Divider(height: 24),

                // Timestamps
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        'Trip Started',
                        _formatTimestamp(item['timestamp']),
                        Icons.play_circle_outline,
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
                        'Total Duration',
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

                const SizedBox(height: 12),

                // Traffic clearance requested
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: trafficRequested ? Colors.green[50] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: trafficRequested ? Colors.green : Colors.grey,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        trafficRequested ? Icons.check_circle : Icons.cancel,
                        color: trafficRequested ? Colors.green : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Traffic Clearance: ${trafficRequested ? "YES" : "NO"}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: trafficRequested ? Colors.green.shade800 : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
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
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
