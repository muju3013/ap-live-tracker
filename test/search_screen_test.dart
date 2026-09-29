import 'dart:convert';

import 'package:ap_live_tracker/screens/search_screen.dart';
import 'package:ap_live_tracker/services/apsrtc_search_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'SearchScreen renders FROM/TO fields, swap button, search button',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SearchScreen()));

      expect(find.text('APSRTC Live'), findsOneWidget);
      expect(find.text('FROM Station'), findsOneWidget);
      expect(find.text('TO Station'), findsOneWidget);
      expect(find.byIcon(Icons.swap_vert_rounded), findsOneWidget);
      expect(find.text('SEARCH BUSES'), findsOneWidget);
      expect(find.text('TIRUPATHI'), findsOneWidget);
      expect(find.text('KADAPA'), findsOneWidget);
    },
  );

  testWidgets(
    'SearchScreen swaps FROM and TO station fields when swap button pressed',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SearchScreen()));

      expect(find.text('TIRUPATHI'), findsOneWidget);
      expect(find.text('KADAPA'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.swap_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('TIRUPATHI'), findsOneWidget);
      expect(find.text('KADAPA'), findsOneWidget);
    },
  );

  testWidgets(
    'SearchScreen performs search and displays result cards with UPCOMING or TRACK LIVE status',
    (WidgetTester tester) async {
      final mockServicesAllResponse = {
        "status": "success",
        "message": "Services found",
        "data": [
          {
            "oprsNo": "64234",
            "serviceId": "CHN4",
            "arrivalTime": "1745",
            "departureDay": 0,
            "arrivalDay": 0,
            "depotName": "CHENNAI",
            "tripNo": 2,
            "journeyDate": "2026-09-27",
            "departureTimeNum": 57300,
            "serviceType": "EXPRESS",
            "serviceStartTime": "03:55 PM",
            "serviceEndTime": "05:45 PM",
            "startCityPlaceId": 14911,
            "endCityPlaceId": 6021,
            "isClose": false,
            "isCancel": false,
            "isDirect": true,
            "exactMatch": true,
            "serviceDocId": "27092026_CHN4_2_JAMMALAMADUGU",
            "sourceName": "TIRUPATHI",
            "destinationName": "KADAPA",
          },
        ],
      };

      final client = MockClient((request) async {
        if (request.url.path.contains('services/all')) {
          return http.Response(jsonEncode(mockServicesAllResponse), 200);
        }
        return http.Response('{"status": "error", "data": []}', 404);
      });

      final searchService = ApsrtcSearchService(client: client);

      await tester.pumpWidget(
        MaterialApp(home: SearchScreen(searchService: searchService)),
      );

      await tester.tap(find.text('SEARCH BUSES'));
      await tester.pumpAndSettle();

      expect(find.text('Service: 64234'), findsOneWidget);
      expect(find.text('TIRUPATHI ➔ KADAPA'), findsOneWidget);
      expect(find.text('TRACK LIVE'), findsOneWidget);
    },
  );
}
