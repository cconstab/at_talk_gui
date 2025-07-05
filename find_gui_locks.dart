#!/usr/bin/env dart
// Script to find and display GUI lock files

import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

void main() async {
  print('🔍 Searching for AtTalk app lock files...\n');

  try {
    // Get the same storage directory that the GUI app uses
    final dir = await getApplicationSupportDirectory();
    final storagePath = dir.path;

    print('📁 GUI storage directory: $storagePath');
    print(
      '🔒 Looking for app lock files with pattern: at_talk_gui_*.lock or at_talk_tui_*.lock\n',
    );
    print(
      'ℹ️  Note: Hive internal lock files (like commit_log_*.lock) are ignored\n',
    );

    // Check main storage directory (only for our app lock files)
    await checkForLockFiles(Directory(storagePath), 'Main storage');

    // DO NOT check commit log directory - it contains Hive's internal lock files
    print('📁 Skipping commit log directory (contains Hive internal locks)');

    // Also check ephemeral storage locations
    final tempDir = Directory.systemTemp;
    final ephemeralPattern = '${tempDir.path}/at_talk_gui/ephemeral';
    print('📁 Checking ephemeral storage: $ephemeralPattern');

    final ephemeralDir = Directory(ephemeralPattern);
    if (await ephemeralDir.exists()) {
      print('   Found ephemeral storage directory');
      await for (final entity in ephemeralDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.lock')) {
          final fileName = entity.path.split('/').last;
          if (_isOurAppLockFile(fileName)) {
            await displayLockFile(entity, 'Ephemeral');
          }
        }
      }
    } else {
      print('   No ephemeral storage found');
    }

    print('\n✅ App lock file search complete!');
    print('\n💡 Manual commands to check app locks only:');
    print(
      '   ls -la "$storagePath"/at_talk_*.lock 2>/dev/null || echo "No app locks"',
    );
    print(
      '   find "${tempDir.path}/at_talk_gui" -name "at_talk_*.lock" 2>/dev/null || echo "No ephemeral app locks"',
    );

    print('\n🧪 To test GUI lock cleanup:');
    print('   1. Run: flutter run');
    print('   2. Check locks with this script');
    print('   3. Close GUI app using the Exit App menu');
    print('   4. Check again with this script - app locks should be gone');

    print('\n🐛 Fixed: No longer touching Hive internal lock files');
    print('   App lock files: at_talk_gui_*.lock, at_talk_tui_*.lock');
    print('   Hive lock files: commit_log_*.lock (now ignored)');
    print(
      '\n🐛 Fixed: GUI now uses isolated commit log for persistent storage',
    );
    print(
      '   Persistent: /path/to/storage/commitLog (was incorrectly /path/to/storage)',
    );
    print('   Ephemeral:  /tmp/at_talk_gui/.../storage/commitLog');
  } catch (e) {
    print('❌ Error searching for lock files: $e');
  }
}

Future<void> checkForLockFiles(Directory dir, String location) async {
  try {
    if (!await dir.exists()) {
      print('   $location directory does not exist\n');
      return;
    }

    final files = await dir
        .list()
        .where((f) => f is File && f.path.endsWith('.lock'))
        .toList();

    // Filter to only our app lock files
    final appLockFiles = files.where((f) {
      final fileName = f.path.split('/').last;
      return _isOurAppLockFile(fileName);
    }).toList();

    if (appLockFiles.isEmpty) {
      print('   $location: No app lock files found\n');
    } else {
      print('   $location: Found ${appLockFiles.length} app lock file(s)');
      for (final file in appLockFiles) {
        await displayLockFile(file as File, location);
      }
      print('');
    }

    // Show info about skipped Hive lock files
    final hiveLockFiles = files.where((f) {
      final fileName = f.path.split('/').last;
      return !_isOurAppLockFile(fileName);
    }).toList();

    if (hiveLockFiles.isNotEmpty) {
      print(
        '   $location: Ignoring ${hiveLockFiles.length} Hive internal lock file(s)',
      );
      for (final file in hiveLockFiles) {
        final fileName = file.path.split('/').last;
        print('     ℹ️  Skipped: $fileName (Hive internal)');
      }
      print('');
    }
  } catch (e) {
    print('   $location: Error checking - $e\n');
  }
}

Future<void> displayLockFile(File lockFile, String location) async {
  try {
    final stat = await lockFile.stat();
    final content = await lockFile.readAsString();
    final fileName = lockFile.path.split('/').last;

    print('     🔒 $fileName');
    print('        Path: ${lockFile.path}');
    print('        Modified: ${stat.modified}');
    print('        Size: ${stat.size} bytes');

    try {
      final lockData = jsonDecode(content);
      if (lockData is Map) {
        print('        Instance ID: ${lockData['instanceId'] ?? 'N/A'}');
        print('        PID: ${lockData['pid'] ?? 'N/A'}');
        print('        Type: ${lockData['type'] ?? 'N/A'}');
        print('        Timestamp: ${lockData['timestamp'] ?? 'N/A'}');
      } else {
        print('        Content: $content');
      }
    } catch (e) {
      print('        Content: $content');
    }
  } catch (e) {
    print('     🔒 ${lockFile.path.split('/').last} (Error reading: $e)');
  }
}

// Check if a lock file is one of our app lock files (not a Hive internal lock file)
bool _isOurAppLockFile(String fileName) {
  return fileName.startsWith('at_talk_gui_') ||
      fileName.startsWith('at_talk_tui_');
}
