import 'package:flutter/material.dart';
import '../../core/utils/atsign_manager.dart';
import '../../core/services/at_talk_service.dart';
import '../../core/services/key_backup_service.dart';

class KeyManagementDialog extends StatefulWidget {
  final String atSign;

  const KeyManagementDialog({required this.atSign, super.key});

  @override
  State<KeyManagementDialog> createState() => _KeyManagementDialogState();
}

class _KeyManagementDialogState extends State<KeyManagementDialog> {
  bool _isLoading = false;
  String? _statusMessage;
  String? _keyStorageStatus;

  @override
  void initState() {
    super.initState();
    _loadKeyStorageStatus();
  }

  Future<void> _loadKeyStorageStatus() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final status = await KeyBackupService.getKeyStorageStatus(widget.atSign);
      setState(() {
        _keyStorageStatus = status;
      });
    } catch (e) {
      setState(() {
        _keyStorageStatus = 'Error checking key storage: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Key Management - ${widget.atSign}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_keyStorageStatus != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storage, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _keyStorageStatus!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

            _buildOptionCard(
              icon: Icons.download,
              title: 'Backup Keys',
              subtitle: 'Export your keys from secure storage to a file',
              onTap: _isLoading ? null : _backupKeys,
            ),

            const SizedBox(height: 12),

            _buildOptionCard(
              icon: Icons.delete_forever,
              title: 'Remove Keys',
              subtitle: 'Delete keys from this device',
              color: Colors.red,
              onTap: _isLoading ? null : _removeKeys,
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Color? color,
  }) {
    final cardColor = color ?? const Color(0xFF2196F3);

    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cardColor.withOpacity(0.1),
          child: Icon(icon, color: cardColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
        enabled: onTap != null,
      ),
    );
  }

  Future<void> _backupKeys() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Preparing key backup from secure storage...';
    });

    try {
      final success = await KeyBackupService.exportKeys(widget.atSign);
      
      if (success) {
        setState(() {
          _statusMessage = 'Keys backed up successfully from secure storage';
        });
      } else {
        setState(() {
          _statusMessage = 'Backup was cancelled or failed';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Backup failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeKeys() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Key Removal'),
        content: Text(
          'Are you sure you want to remove keys for ${widget.atSign}?\n\n'
          'This action cannot be undone. You will need to re-authenticate or import backup keys to use this atSign again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Removing keys...';
    });

    try {
      // Use comprehensive cleanup for complete removal
      await AtTalkService.completeAtSignCleanup(widget.atSign);

      // Remove from atsign information
      await removeAtsignInformation(widget.atSign);

      setState(() {
        _statusMessage =
            'Keys and all storage completely removed. Please restart the app.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to remove keys: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
