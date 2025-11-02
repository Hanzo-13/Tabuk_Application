import 'package:flutter/material.dart';
import '../services/offline_sync_service.dart';
import '../services/connectivity_service.dart';
import '../widgets/offline_sync_dialog.dart';
import '../services/auth_service.dart';

/// Widget showing offline sync status and allowing manual sync
class OfflineStatusWidget extends StatefulWidget {
  final bool showSyncButton;
  
  const OfflineStatusWidget({
    super.key,
    this.showSyncButton = true,
  });

  @override
  State<OfflineStatusWidget> createState() => _OfflineStatusWidgetState();
}

class _OfflineStatusWidgetState extends State<OfflineStatusWidget> {
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isConnected = true;
  Map<String, dynamic>? _syncStatus;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadSyncStatus();
    // Listen to connectivity changes
    _connectivityService.connectivityStream.listen((info) {
      if (mounted) {
        setState(() {
          _isConnected = info.isConnected;
        });
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivity = await _connectivityService.checkConnection();
    if (mounted) {
      setState(() {
        _isConnected = connectivity.isConnected;
      });
    }
  }

  Future<void> _loadSyncStatus() async {
    final userId = AuthService.currentUser?.uid;
    final status = OfflineSyncService.getSyncStatus(userId: userId);
    if (mounted) {
      setState(() {
        _syncStatus = status;
      });
    }
  }

  Future<void> _handleSync() async {
    if (!_isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection. Cannot sync data.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final userId = AuthService.currentUser?.uid;
    final results = await OfflineSyncDialog.show(
      context,
      userId: userId,
      downloadImages: true,
    );

    // Reload status after sync
    if (results != null && mounted) {
      await _loadSyncStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getSyncSummary(results)),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  String _getSyncSummary(Map<String, SyncResult> results) {
    final parts = <String>[];
    if (results.containsKey('hotspots')) {
      parts.add('${results['hotspots']!.count} hotspots');
    }
    if (results.containsKey('events')) {
      parts.add('${results['events']!.count} events');
    }
    if (results.containsKey('trips')) {
      parts.add('${results['trips']!.count} trips');
    }
    return 'Synced: ${parts.join(', ')}';
  }

  String _getLastSyncText(String? lastSyncTime) {
    if (lastSyncTime == null) return 'Never';
    try {
      final syncTime = DateTime.parse(lastSyncTime);
      final now = DateTime.now();
      final difference = now.difference(syncTime);
      
      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: _isConnected ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Offline Access',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_syncStatus != null) ...[
              _buildStatusRow(
                'Hotspots',
                _syncStatus!['hotspots_count'] ?? 0,
                _getLastSyncText(_syncStatus!['hotspots_last_sync']?.toString()),
              ),
              const SizedBox(height: 8),
              _buildStatusRow(
                'Events',
                _syncStatus!['events_count'] ?? 0,
                _getLastSyncText(_syncStatus!['events_last_sync']?.toString()),
              ),
              const SizedBox(height: 8),
              if (_syncStatus!['trips_last_sync'] != null)
                _buildStatusRow(
                  'Trips',
                  _syncStatus!['trips_count'] ?? 0,
                  _getLastSyncText(_syncStatus!['trips_last_sync']?.toString()),
                ),
              const SizedBox(height: 12),
            ],
            if (widget.showSyncButton)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isConnected ? _handleSync : null,
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('Download for Offline'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            if (!_isConnected)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Connect to internet to sync data',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, int count, String lastSync) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Row(
          children: [
            Text(
              '$count items',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(width: 8),
            Text(
              '• $lastSync',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

