#!/usr/bin/env dart

import 'dart:io';
import 'package:at_talk_gui/main.dart' as app;

void main(List<String> args) {
  // Check if Flutter is available for GUI mode
  if (Platform.environment['FLUTTER_ROOT'] != null) {
    app.main();
  } else {
    print('Flutter not found. Please ensure Flutter is installed and in PATH.');
    exit(1);
  }
}
