#!/usr/bin/env dart
// Simple test to verify TUI lock file cleanup

import 'dart:io';

void main() async {
  print('🧪 Testing TUI lock file cleanup...');

  final testDir = Directory('/tmp/attalk_manual_test');
  await testDir.create(recursive: true);

  print('📁 Test directory: ${testDir.path}');
  print('🔍 Initial lock files:');
  await listLockFiles(testDir);

  print('');
  print('🚀 Now manually test the TUI:');
  print(
    '   1. Run: dart run bin/at_talk_tui.dart -a @test -t @other -s ${testDir.path}',
  );
  print('   2. Wait for it to start (it may fail due to missing atsign)');
  print('   3. Check lock files with: ls -la ${testDir.path}/*.lock');
  print('   4. Exit using either:');
  print('      - Type "/exit" in the chat');
  print('      - Press Ctrl+C');
  print('   5. Check lock files again to see if they were cleaned up');
  print('');
  print('Press Enter when you\'re done testing...');
  stdin.readLineSync();

  print('🔍 Final lock files:');
  await listLockFiles(testDir);

  // Cleanup
  try {
    await testDir.delete(recursive: true);
    print('✅ Test directory cleaned up');
  } catch (e) {
    print('⚠️ Could not clean up test directory: $e');
  }
}

Future<void> listLockFiles(Directory dir) async {
  try {
    final files = await dir
        .list()
        .where((f) => f.path.endsWith('.lock'))
        .toList();
    if (files.isEmpty) {
      print('   No lock files found');
    } else {
      for (final file in files) {
        final stat = await file.stat();
        print('   ${file.path.split('/').last} (modified: ${stat.modified})');
      }
    }
  } catch (e) {
    print('   Error listing files: $e');
  }
}
