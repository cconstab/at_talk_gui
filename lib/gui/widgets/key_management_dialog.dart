import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../core/utils/atsign_manager.dart';

class KeyManagementDialog extends StatefulWidget {
  final String atSign;

  const KeyManagementDialog({required this.atSign, super.key});

  @override
  State<KeyManagementDialog> createState() => _KeyManagementDialogState();
}

class _KeyManagementDialogState extends State<KeyManagementDialog> {
  bool _isLoading = false;
  String? _statusMessage;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Key Management - ${widget.atSign}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                    Expanded(child: Text(_statusMessage!, style: const TextStyle(fontSize: 14))),
                  ],
                ),
              ),

            _buildOptionCard(
              icon: Icons.download,
              title: 'Backup Keys',
              subtitle: 'Save your atKeys to a secure location',
              onTap: _isLoading ? null : _backupKeys,
            ),

            const SizedBox(height: 12),

            _buildOptionCard(
              icon: Icons.upload,
              title: 'Import Keys',
              subtitle: 'Load atKeys from a backup file',
              onTap: _isLoading ? null : _importKeys,
            ),

            const SizedBox(height: 12),

            _buildOptionCard(
              icon: Icons.delete_forever,
              title: 'Remove Keys',
              subtitle: 'Delete keys from this device',
              color: Colors.red,
              onTap: _isLoading ? null : _removeKeys,
            ),

            if (_isLoading) const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.of(context).pop(), child: const Text('Close')),
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
      _statusMessage = 'Preparing key backup...';
    });

    try {
      // Get the directory where keys are stored
      final appSupportDir = await getApplicationSupportDirectory();
      final keysDir = Directory('${appSupportDir.path}/keys');

      if (!keysDir.existsSync()) {
        throw Exception('Keys directory not found');
      }

      // Find the key file for this atSign
      final keyFiles = keysDir
          .listSync()
          .where((file) => file.path.contains(widget.atSign.replaceAll('@', '')))
          .toList();

      if (keyFiles.isEmpty) {
        throw Exception('No key files found for ${widget.atSign}');
      }

      // Let user choose where to save the backup
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save atKeys backup',
        fileName: '${widget.atSign.replaceAll('@', '')}_atkeys_backup.zip',
        type: FileType.any,
      );

      if (outputPath != null) {
        // Copy the key file to the selected location
        final keyFile = File(keyFiles.first.path);
        final backupFile = File(outputPath);

        await keyFile.copy(backupFile.path);

        setState(() {
          _statusMessage = 'Keys backed up successfully to ${backupFile.path}';
        });
      } else {
        setState(() {
          _statusMessage = 'Backup cancelled';
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

  Future<void> _importKeys() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Preparing to import keys...';
    });

    try {
      // Let user select the key file to import
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowedExtensions: null,
        dialogTitle: 'Select atKeys file to import',
      );

      if (result != null && result.files.single.path != null) {
        final selectedFile = File(result.files.single.path!);

        // Get the keys directory
        final appSupportDir = await getApplicationSupportDirectory();
        final keysDir = Directory('${appSupportDir.path}/keys');

        if (!keysDir.existsSync()) {
          keysDir.createSync(recursive: true);
        }

        // Generate the target file name based on the atSign
        final targetFileName = '${widget.atSign.replaceAll('@', '')}_key.atKeys';
        final targetFile = File('${keysDir.path}/$targetFileName');

        // Copy the selected file to the keys directory
        await selectedFile.copy(targetFile.path);

        setState(() {
          _statusMessage = 'Keys imported successfully. You may need to restart the app.';
        });
      } else {
        setState(() {
          _statusMessage = 'Import cancelled';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Import failed: ${e.toString()}';
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
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
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
      // Remove from keychain - use resetAtSignFromKeychain for complete cleanup
      final keyChainManager = KeyChainManager.getInstance();
      await keyChainManager.resetAtSignFromKeychain(widget.atSign);

      // Remove from local storage
      final appSupportDir = await getApplicationSupportDirectory();
      final keysDir = Directory('${appSupportDir.path}/keys');

      if (keysDir.existsSync()) {
        final keyFiles = keysDir
            .listSync()
            .where((file) => file.path.contains(widget.atSign.replaceAll('@', '')))
            .toList();

        for (final file in keyFiles) {
          await file.delete();
        }
      }

      // Remove from atsign information
      await removeAtsignInformation(widget.atSign);

      setState(() {
        _statusMessage = 'Keys removed successfully. Please restart the app.';
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
