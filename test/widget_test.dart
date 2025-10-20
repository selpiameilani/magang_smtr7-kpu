import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_kpu/main.dart';

void main() {
  testWidgets('App initialization test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Wait for splash screen
    await tester.pump(const Duration(seconds: 3));

    // Verify that splash screen text is present
    expect(find.text('Sistem Informasi Buku Tamu'), findsOneWidget);
  });
}