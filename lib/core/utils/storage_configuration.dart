import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'temp_directory_utils.dart';

class StorageConfiguration {
  final bool isEphemeral;
  final String atSign;
  final String namespace;
  final String uuid;

  StorageConfiguration({
    required this.isEphemeral,
    required this.atSign,
    required this.namespace,
    String? uuid,
  }) : uuid = uuid ?? const Uuid().v4();

  /// Get the storage path based on configuration
  Future<String> getStoragePath() async {
    if (isEphemeral) {
      return TempDirectoryUtils.getEphemeralStoragePath(atSign, uuid);
    } else {
      final dir = await getApplicationSupportDirectory();
      return '${dir.path}/.$namespace/$atSign/storage';
    }
  }

  /// Get the fallback storage path for multi-instance support
  Future<String> getFallbackStoragePath() async {
    if (isEphemeral) {
      // For ephemeral, fallback is the same as primary
      return getStoragePath();
    } else {
      final dir = await getApplicationSupportDirectory();
      return '${dir.path}/.$namespace/$atSign/$uuid/storage';
    }
  }

  /// Get the commit log path
  Future<String> getCommitLogPath() async {
    final storagePath = await getStoragePath();
    return '$storagePath/commitLog';
  }

  /// Get the files/download path
  Future<String> getFilesPath() async {
    if (isEphemeral) {
      return TempDirectoryUtils.getEphemeralFilesPath(atSign, uuid);
    } else {
      final dir = await getApplicationSupportDirectory();
      return '${dir.path}/.$namespace/$atSign/files';
    }
  }

  /// Check if database is locked (for multi-instance detection)
  static bool isDatabaseLockError(dynamic exception) {
    final exceptionStr = exception.toString().toLowerCase();
    return exceptionStr.contains('database') &&
        (exceptionStr.contains('lock') || exceptionStr.contains('busy'));
  }

  /// Check if storage is already in use by examining Hive database files
  static Future<bool> isStorageInUse(String storagePath) async {
    try {
      // Check for common Hive database file patterns
      final directory = Directory(storagePath);
      if (!await directory.exists()) {
        return false; // Storage doesn't exist, so it's not in use
      }

      // Look for .hive files (Hive database files)
      final files = await directory.list().toList();
      for (var file in files) {
        if (file is File && file.path.endsWith('.hive')) {
          // Try to open the file to see if it's locked
          try {
            final randomAccessFile = await file.open(mode: FileMode.append);
            await randomAccessFile.close();
          } catch (e) {
            // If we can't open it, it's likely in use
            return true;
          }
        }
      }

      // Also check the commit log directory
      final commitLogDir = Directory('$storagePath/commitLog');
      if (await commitLogDir.exists()) {
        final commitLogFiles = await commitLogDir.list().toList();
        for (var file in commitLogFiles) {
          if (file is File) {
            try {
              final randomAccessFile = await file.open(mode: FileMode.append);
              await randomAccessFile.close();
            } catch (e) {
              return true; // Commit log files are locked
            }
          }
        }
      }

      return false; // Storage appears to be available
    } catch (e) {
      // If we can't check, assume it's safe to proceed
      return false;
    }
  }

  /// Check if an exception indicates storage corruption
  static bool isStorageCorruptionError(dynamic exception) {
    final exceptionStr = exception.toString().toLowerCase();
    return exceptionStr.contains('filesystemexception') ||
        exceptionStr.contains('readinto failed') ||
        exceptionStr.contains('.hive') ||
        exceptionStr.contains('corrupted') ||
        exceptionStr.contains('invalid format') ||
        exceptionStr.contains('bad hive file') ||
        exceptionStr.contains('no such file or directory') ||
        exceptionStr.contains('cannot open file') ||
        exceptionStr.contains('permission denied');
  }
}
