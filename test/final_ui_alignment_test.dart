import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ap_live_tracker/models/apsrtc_station.dart';
import 'package:ap_live_tracker/services/apsrtc_place_repository.dart';
import 'package:ap_live_tracker/services/apsrtc_vehicle_search_service.dart';
import 'package:ap_live_tracker/services/recent_search_service.dart';
import 'package:ap_live_tracker/services/recent_track_service.dart';
import 'package:ap_live_tracker/widgets/bottom_nav_shell.dart';
import 'package:ap_live_tracker/widgets/station_route_card.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('FINAL UI ALIGNMENT TASK - STITCH UI & FEATURES', () {
    test('ApsrtcVehicleSearchService cleanVehicleNumber formatting', () {
      expect(
        ApsrtcVehicleSearchService.cleanVehicleNumber('ap 39 x 6803'),
        equals('AP39X6803'),
      );
      expect(
        ApsrtcVehicleSearchService.cleanVehicleNumber('AP-39-X-6803'),
        equals('AP39X6803'),
      );
    });

    test('RecentSearchItem JSON serialization', () {
      final item = RecentSearchItem(
        fromStation: const ApsrtcStation(
          placeId: '14911',
          linkPlaceId: '14911',
          placeName: 'TIRUPATHI',
        ),
        toStation: const ApsrtcStation(
          placeId: '6021',
          linkPlaceId: '6021',
          placeName: 'KADAPA',
        ),
        serviceType: 'Express',
        distanceText: '142 km',
        timestamp: DateTime(2026, 9, 28, 12, 0),
      );

      final json = item.toJson();
      final parsed = RecentSearchItem.fromJson(json);

      expect(parsed.routeTitle, equals('TIRUPATHI → KADAPA'));
      expect(parsed.subtitle, equals('Express • 142 km'));
      expect(parsed.fromStation.placeId, equals('14911'));
      expect(parsed.toStation.placeId, equals('6021'));
    });

    test('RecentTrackItem JSON serialization and display string', () {
      final item = RecentTrackItem(
        vehicleNumber: 'AP39X6803',
        serviceDocId: '27092026_CT24_4_PILER',
        oprsNo: 'CT24/4',
        serviceType: 'PALLEVELUGU',
        routeSummary: 'CHITTOOR → PILER',
        lastTrackedAt: DateTime.now(),
      );

      final json = item.toJson();
      final parsed = RecentTrackItem.fromJson(json);

      expect(parsed.vehicleNumber, equals('AP39X6803'));
      expect(parsed.displayService, equals('Service #CT24/4 • PALLEVELUGU'));
      expect(parsed.formattedTime, equals('Just now'));
    });

    testWidgets(
      'BottomNavShell renders Home and Track tabs and switches screen',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final repo = ApsrtcPlaceRepository();
        repo.loadPlacesFromRaw(
          jsonEncode({
            'places': [
              {
                'placeId': '14911',
                'placeName': 'TIRUPATHI',
                'mandalName': 'TIRUPATI URBAN',
                'pinCode': '517501',
              },
              {
                'placeId': '6021',
                'placeName': 'KADAPA',
                'mandalName': 'KADAPA',
                'pinCode': '516001',
              },
            ],
          }),
        );

        final searchSvc = RecentSearchService(prefs: prefs);
        final trackSvc = RecentTrackService(prefs: prefs);

        await tester.pumpWidget(
          MaterialApp(
            home: BottomNavShell(
              placeRepository: repo,
              recentSearchService: searchSvc,
              recentTrackService: trackSvc,
            ),
          ),
        );

        await tester.pump(Duration.zero);
        await tester.pump();

        // Verify Home tab items
        expect(find.text('AP BUS LIVE'), findsOneWidget);
        expect(find.text('Where are you going?'), findsOneWidget);
        expect(find.text('SEARCH BUSES'), findsOneWidget);

        // Verify bottom navigation bar tabs
        expect(find.text('Home'), findsWidgets);
        expect(find.text('Track'), findsWidgets);

        // Tap Track tab
        await tester.tap(find.text('Track').last);
        await tester.pump(Duration.zero);
        await tester.pump();

        // Verify Track screen item
        expect(find.text('TRACK BUS'), findsOneWidget);
        expect(find.text('Ex: AP39X6803'), findsOneWidget);
      },
    );

    testWidgets('HomeScreen renders StationRouteCard with Stitch styling', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StationRouteCard(
              fromStation: const ApsrtcStation(
                placeId: '14911',
                linkPlaceId: '14911',
                placeName: 'TIRUPATHI',
                mandalName: 'TIRUPATI URBAN',
                pinCode: '517501',
              ),
              toStation: const ApsrtcStation(
                placeId: '6021',
                linkPlaceId: '6021',
                placeName: 'KADAPA',
                mandalName: 'KADAPA',
                pinCode: '516001',
              ),
              onSelectFrom: () {},
              onSelectTo: () {},
              onSwap: () {},
              onSearch: () {},
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('FROM'), findsOneWidget);
      expect(find.text('TIRUPATHI'), findsOneWidget);

      expect(find.text('TO'), findsOneWidget);
      expect(find.text('KADAPA'), findsOneWidget);

      expect(find.byIcon(Icons.swap_vert_rounded), findsOneWidget);
      expect(find.text('SEARCH BUSES'), findsOneWidget);
    });
  });
}
