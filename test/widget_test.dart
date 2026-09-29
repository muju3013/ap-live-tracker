import 'dart:convert';

import 'package:ap_live_tracker/screens/live_bus_screen.dart';
import 'package:ap_live_tracker/services/apsrtc_live_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('LiveBusScreen renders status card and telemetry info', (
    WidgetTester tester,
  ) async {
    final mockResponse = {
      "fields": {
        "vehicleNumber": {"stringValue": "AP39X6803"},
        "oprsNo": {"stringValue": "CT24/4"},
        "serviceType": {"stringValue": "PALLEVELUGU"},
        "latitude": {"doubleValue": 13.654401},
        "longitude": {"doubleValue": 78.944195},
        "speed": {"stringValue": "0.0"},
        "locationBearing": {"doubleValue": 104.66},
        "locationAltitude": {"doubleValue": 502.1},
        "locationTime": {"stringValue": "1790500001443"},
        "refreshedAt": {"integerValue": "1790500001443"},
        "isOnline": {"stringValue": "1"},
        "serviceDocId": {"stringValue": "27092026_CT24_4_PILER"},
      },
    };

    final client = MockClient((request) async {
      return http.Response(jsonEncode(mockResponse), 200);
    });

    final service = ApsrtcLiveService(client: client);

    await tester.pumpWidget(
      MaterialApp(
        home: LiveBusScreen(
          service: service,
          pollInterval: const Duration(seconds: 100),
        ),
      ),
    );

    // Initial loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let async HTTP request resolve
    await tester.pumpAndSettle();

    // Verify Vehicle and Service details
    expect(find.text('Vehicle AP39X6803'), findsOneWidget);
    expect(find.text('Service: CT24/4'), findsWidgets);

    // Verify Telemetry details
    expect(find.textContaining('13.654'), findsWidgets);
    expect(find.textContaining('78.944'), findsWidgets);

    // Verify Recenter FloatingActionButton when panned
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('LiveBusScreen displays error banner on request failure', (
    WidgetTester tester,
  ) async {
    final client = MockClient((request) async {
      return http.Response('Server error', 500);
    });

    final service = ApsrtcLiveService(client: client);

    await tester.pumpWidget(
      MaterialApp(
        home: LiveBusScreen(
          service: service,
          pollInterval: const Duration(seconds: 100),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Live location temporarily unavailable'), findsOneWidget);
  });
}
