import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_talk_gui/main.dart';

void main() {
  testWidgets('AtTalk app loads', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AtTalkApp());

    // Verify that the splash screen is shown
    expect(find.text('AtTalk'), findsOneWidget);
  });
}
