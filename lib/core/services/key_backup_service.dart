import 'dart:convert';
import 'dart:typed_data';
import 'package:at_backupkey_flutter/services/backupkey_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Service for backing up and restoring atSign keys from secure/biometric storage
/// Based on NoPorts' approach using at_backupkey_flutter
class KeyBackupService {
  /// Export keys from secure storage to a user-selected file location
  /// This is the primary method that should work regardless of how keys are stored
  static Future<bool> exportKeys(String atSign) async {
    try {
      // Try to get encrypted keys from secure storage first (NoPorts approach)
      Map<String, dynamic>? encryptedKeys;
      try {
        print('Attempting to retrieve keys from secure storage for $atSign...');
        encryptedKeys = await BackUpKeyService.getEncryptedKeys(atSign);
        print('Successfully retrieved ${encryptedKeys.length} keys from secure storage for $atSign');
      } catch (e) {
        print('Could not retrieve keys from secure storage for $atSign: $e');
        print('Falling back to file-based backup...');
        // Fall back to file-based backup if secure storage fails
        return await _exportKeysFromFiles(atSign);
      }

      if (encryptedKeys.isEmpty) {
        print('No keys found in secure storage for $atSign, trying file-based backup');
        return await _exportKeysFromFiles(atSign);
      }

      // Convert encrypted keys to JSON and then to bytes
      final keyString = jsonEncode(encryptedKeys);
      final List<int> codeUnits = keyString.codeUnits;
      final Uint8List data = Uint8List.fromList(codeUnits);

      // Let user choose where to save the backup
      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save atKeys backup',
        fileName: '${atSign.replaceAll('@', '')}_atkeys_backup.atKeys',
        type: FileType.any,
      );

      if (outputPath == null) {
        print('User cancelled backup');
        return false;
      }

      // Write the encrypted keys to the chosen location
      final File backupFile = File(outputPath);
      await backupFile.create(recursive: true);
      await backupFile.writeAsBytes(data);

      print('Keys backed up successfully to $outputPath');
      return true;
    } catch (e) {
      print('Error during key export: $e');
      return false;
    }
  }

  /// Fall back method: export keys from file-based storage
  static Future<bool> _exportKeysFromFiles(String atSign) async {
    try {
      // Get the directory where keys are stored
      final appSupportDir = await getApplicationSupportDirectory();
      final keysDir = Directory('${appSupportDir.path}/keys');

      if (!keysDir.existsSync()) {
        print('Keys directory does not exist: ${keysDir.path}');
        return false;
      }

      // Find the key file for this atSign
      final keyFiles = keysDir.listSync().where((file) => file.path.contains(atSign.replaceAll('@', ''))).toList();

      if (keyFiles.isEmpty) {
        print('No key files found for $atSign in ${keysDir.path}');
        return false;
      }

      // Let user choose where to save the backup
      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save atKeys backup',
        fileName: '${atSign.replaceAll('@', '')}_atkeys_backup.atKeys',
        type: FileType.any,
      );

      if (outputPath == null) {
        print('User cancelled backup');
        return false;
      }

      // Copy the key file to the selected location
      final keyFile = File(keyFiles.first.path);
      final backupFile = File(outputPath);
      await keyFile.copy(backupFile.path);

      print('File-based keys backed up successfully to $outputPath');
      return true;
    } catch (e) {
      print('Error during file-based key export: $e');
      return false;
    }
  }

  /// Check if keys are available for backup (either in secure storage or files)
  static Future<bool> areKeysAvailable(String atSign) async {
    print('Checking if keys are available for backup for $atSign...');
    
    // Check secure storage first
    try {
      print('Checking secure storage...');
      final encryptedKeys = await BackUpKeyService.getEncryptedKeys(atSign);
      if (encryptedKeys.isNotEmpty) {
        print('Found ${encryptedKeys.length} keys in secure storage for $atSign');
        return true;
      }
      print('No keys found in secure storage for $atSign');
    } catch (e) {
      print('Could not check secure storage for $atSign: $e');
    }

    // Check file-based storage
    try {
      print('Checking file-based storage...');
      final appSupportDir = await getApplicationSupportDirectory();
      final keysDir = Directory('${appSupportDir.path}/keys');

      if (!keysDir.existsSync()) {
        print('Keys directory does not exist: ${keysDir.path}');
        return false;
      }

      final keyFiles = keysDir.listSync().where((file) => file.path.contains(atSign.replaceAll('@', ''))).toList();

      if (keyFiles.isNotEmpty) {
        print('Found ${keyFiles.length} key files in file storage for $atSign');
        return true;
      } else {
        print('No key files found in file storage for $atSign');
        return false;
      }
    } catch (e) {
      print('Error checking file-based keys for $atSign: $e');
      return false;
    }
  }

  /// Get a status message about where keys are stored
  static Future<String> getKeyStorageStatus(String atSign) async {
    bool secureStorageAvailable = false;
    bool fileStorageAvailable = false;

    // Check secure storage
    try {
      final encryptedKeys = await BackUpKeyService.getEncryptedKeys(atSign);
      secureStorageAvailable = encryptedKeys.isNotEmpty;
    } catch (e) {
      // Secure storage not available or no keys
    }

    // Check file-based storage
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      final keysDir = Directory('${appSupportDir.path}/keys');

      if (keysDir.existsSync()) {
        final keyFiles = keysDir.listSync().where((file) => file.path.contains(atSign.replaceAll('@', ''))).toList();
        fileStorageAvailable = keyFiles.isNotEmpty;
      }
    } catch (e) {
      // File storage not available
    }

    if (secureStorageAvailable && fileStorageAvailable) {
      return 'Keys found in both secure storage and files';
    } else if (secureStorageAvailable) {
      return 'Keys found in secure storage (recommended)';
    } else if (fileStorageAvailable) {
      return 'Keys found in file storage';
    } else {
      return 'No keys found. Ensure the atSign is properly onboarded.';
    }
  }
}
