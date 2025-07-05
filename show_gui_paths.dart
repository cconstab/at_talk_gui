#!/usr/bin/env dart

import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() async {
  final dir = await getApplicationSupportDirectory();
  print('GUI storage path: ${dir.path}');
  print('GUI lock files location: ${dir.path}/*.lock');
  print('');
  print('To check for GUI lock files, run:');
  print('ls -la "${dir.path}"/*.lock');
  print('ls -la "${dir.path}/commitLog"/*.lock');
  print('');
  print('For ephemeral storage:');
  final tempDir = Directory.systemTemp;
  print('find "${tempDir.path}/at_talk_gui" -name "*.lock" 2>/dev/null');
}
