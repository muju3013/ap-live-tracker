import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ap_live_tracker/screens/splash_screen.dart';

void main() {
  testWidgets('SplashScreen renders logo asset', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(),
      ),
    );

    // Verify SplashScreen renders Image asset
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    // Advance timer past splash duration
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 300));
  });
}
