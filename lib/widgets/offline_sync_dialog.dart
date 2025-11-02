import 'package:flutter/material.dart';
import '../services/offline_sync_service.dart';

/// Dialog widget showing offline sync progress
class OfflineSyncDialog extends StatefulWidget {
  final String? userId;
  final bool downloadImages;

  const OfflineSyncDialog({
    super.key,
    this.userId,
    this.downloadImages = true,
  });

  @override
  State<OfflineSyncDialog> createState() => _OfflineSyncDialogState();

  /// Show sync dialog and return sync results
  static Future<Map<String, SyncResult>?> show(
    BuildContext context, {
    String? userId,
    bool downloadImages = true,
  }) async {
    return showDialog<Map<String, SyncResult>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => OfflineSyncDialog(
        userId: userId,
        downloadImages: downloadImages,
      ),
    );
  }
}

class _OfflineSyncDialogState extends State<OfflineSyncDialog> {
  final Map<String, double> _progress = {};
  final Map<String, String> _status = {};
  final Map<String, SyncResult> _results = {};
  bool _isComplete = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startSync();
  }

  Future<void> _startSync() async {
    // Set up progress tracking
    OfflineSyncService.onProgress = (dataType, progress, message) {
      if (mounted) {
        setState(() {
          _progress[dataType] = progress;
          _status[dataType] = message;
        });
      }
    };

    OfflineSyncService.onComplete = (dataType, message) {
      if (mounted) {
        setState(() {
          _status[dataType] = message;
          if (dataType == 'all') {
            _isComplete = true;
          }
        });
      }
    };

    OfflineSyncService.onError = (dataType, error) {
      if (mounted) {
        setState(() {
          _error = error;
          _status[dataType] = 'Error: $error';
        });
      }
    };

    try {
      final results = await OfflineSyncService.syncAllData(
        userId: widget.userId,
        downloadImages: widget.downloadImages,
        progressCallback: (dataType, progress, message) {
          if (mounted) {
            setState(() {
              _progress[dataType] = progress;
              _status[dataType] = message;
            });
          }
        },
      );
      
      _results.addAll(results);
      
      if (mounted) {
        setState(() {
          _isComplete = true;
        });
        // Close dialog after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop(results);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isComplete = true;
        });
      }
    }
  }

  double get _overallProgress {
    if (_progress.isEmpty) return 0.0;
    final values = _progress.values;
    return values.reduce((a, b) => a + b) / values.length;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => _isComplete,
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.cloud_download, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('Downloading for Offline'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Overall progress
              _buildProgressItem(
                'Overall Progress',
                _overallProgress,
                _status['all'] ?? 'Preparing...',
              ),
              
              const SizedBox(height: 16),
              
              // Individual items
              _buildProgressItem(
                'Hotspots',
                _progress['hotspots'] ?? 0.0,
                _status['hotspots'] ?? 'Waiting...',
              ),
              
              const SizedBox(height: 12),
              
              _buildProgressItem(
                'Events',
                _progress['events'] ?? 0.0,
                _status['events'] ?? 'Waiting...',
              ),
              
              if (widget.userId != null) ...[
                const SizedBox(height: 12),
                _buildProgressItem(
                  'Trips',
                  _progress['trips'] ?? 0.0,
                  _status['trips'] ?? 'Waiting...',
                ),
              ],
            ],
          ),
        ),
        actions: _isComplete
            ? [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_results),
                  child: const Text('Done'),
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildProgressItem(String label, double progress, String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(
            progress < 1.0 ? Colors.blue : Colors.green,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          status,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

