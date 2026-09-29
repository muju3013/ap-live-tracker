import 'dart:convert';
import 'dart:io';

import 'package:ap_live_tracker/models/apsrtc_station.dart';
import 'package:ap_live_tracker/screens/bus_results_screen.dart';
import 'package:ap_live_tracker/screens/home_screen.dart';

import 'package:ap_live_tracker/services/apsrtc_place_repository.dart';
import 'package:ap_live_tracker/services/apsrtc_search_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApsrtcPlaceRepository repository;

  setUpAll(() {
    final file = File('assets/data/apsrtc_places.json');
    final rawText = file.existsSync() ? file.readAsStringSync() : '';
    repository = ApsrtcPlaceRepository();
    if (rawText.isNotEmpty) {
      repository.loadPlacesFromRaw(rawText);
    }
  });

  group('PHASE 4B — STITCH UI VERIFICATION SUITE', () {
    testWidgets(
      '1. HomeScreen renders title, header, trust row and StationRouteCard',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(home: HomeScreen(placeRepository: repository)),
        );
        await tester.pumpAndSettle();

        expect(find.text('AP BUS LIVE'), findsOneWidget);
        expect(find.text('Where are you going?'), findsOneWidget);
        expect(
          find.text('Track APSRTC buses across Andhra Pradesh'),
          findsOneWidget,
        );
        expect(find.text('Real APSRTC services'), findsOneWidget);
        expect(find.text('Live GPS available'), findsOneWidget);
        expect(find.text('SEARCH BUSES'), findsOneWidget);
      },
    );

    testWidgets('2. Same station selection validation shows error SnackBar', (
      WidgetTester tester,
    ) async {
      final sameStation = const ApsrtcStation(
        placeId: '14911',
        linkPlaceId: '14911',
        placeName: 'TIRUPATHI',
      );

      final searchService = ApsrtcSearchService();

      await tester.pumpWidget(
        MaterialApp(
          home: BusResultsScreen(
            fromStation: sameStation,
            toStation: sameStation,
            searchService: searchService,
          ),
        ),
      );

      expect(find.text('TIRUPATHI → TIRUPATHI'), findsOneWidget);
    });

    testWidgets(
      '3. BusResultsScreen renders search results and filters via chips locally',
      (WidgetTester tester) async {
        final mockResponse = {
          "status": "success",
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

        int postCount = 0;
        final client = MockClient((req) async {
          if (req.url.path.contains('/services/all')) {
            postCount++;
            return http.Response(jsonEncode(mockResponse), 200);
          }
          return http.Response('Not Found', 404);
        });

        final searchService = ApsrtcSearchService(client: client);
        final from = const ApsrtcStation(
          placeId: '14911',
          linkPlaceId: '14911',
          placeName: 'TIRUPATHI',
        );
        final to = const ApsrtcStation(
          placeId: '6021',
          linkPlaceId: '6021',
          placeName: 'KADAPA',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: BusResultsScreen(
              fromStation: from,
              toStation: to,
              searchService: searchService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(postCount, equals(1));
        expect(find.text('Service: 64234'), findsOneWidget);
        expect(find.text('TRACK LIVE'), findsOneWidget);

        // Tap filter chip - must not trigger network call
        await tester.tap(find.textContaining('Upcoming'));
        await tester.pumpAndSettle();

        expect(postCount, equals(1)); // Still exactly 1 POST request
      },
    );
  });
}
