import 'package:ap_live_tracker/models/apsrtc_route_stop.dart';
import 'package:ap_live_tracker/models/bus_live_location.dart';
import 'package:ap_live_tracker/screens/live_bus_screen.dart';
import 'package:ap_live_tracker/services/apsrtc_live_service.dart';
import 'package:ap_live_tracker/services/apsrtc_route_stops_service.dart';
import 'package:ap_live_tracker/utils/trip_progress_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockLiveService extends ApsrtcLiveService {
  final BusLiveLocation locationToReturn;
  MockLiveService(this.locationToReturn);

  @override
  Future<BusLiveLocation> fetchLiveLocation({
    required String serviceDocId,
    String? customUrl,
  }) async {
    return locationToReturn;
  }
}

class MockRouteStopsService extends ApsrtcRouteStopsService {
  final ApsrtcRouteSegmentResult segmentToReturn;
  MockRouteStopsService(this.segmentToReturn);

  @override
  Future<ApsrtcRouteSegmentResult> resolveRouteStops({
    required String serviceDocId,
    String? wayPointString,
    dynamic fromStation,
    dynamic toStation,
    String? fromName,
    String? toName,
    Map<String, String>? enrichedStopNames,
    Map<String, ApsrtcRouteStop>? enrichedStopMetadata,
  }) async {
    return segmentToReturn;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PHASE 4E — Unit Tests', () {
    test(
      '1. TrackingFreshnessClassifier formatAge formats raw seconds properly',
      () {
        expect(TrackingFreshnessClassifier.formatAge(12), '12 sec ago');
        expect(TrackingFreshnessClassifier.formatAge(180), '3 min ago');
        expect(TrackingFreshnessClassifier.formatAge(33006), '9h 10m ago');
      },
    );

    test('2. TripProgressResolver classifies completed, active, stale, and upcoming trips', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // Completed trip
      final completedLoc = BusLiveLocation(
        vehicleNumber: 'AP39X6803',
        oprsNo: 'CT24/4',
        serviceType: 'PALLEVELUGU',
        latitude: 13.6547,
        longitude: 78.9445,
        speed: 0.0,
        locationBearing: 0,
        locationAltitude: 0,
        locationTime: '$nowMs',
        refreshedAt: nowMs,
        isOnline: true,
        serviceDocId: '27092026_CT24_4_PILER',
        tripStatus: '2',
        serviceEndedTimeStamp: nowMs,
      );

      final completedInfo = TripProgressResolver.resolve(
        location: completedLoc,
      );
      expect(completedInfo.isCompleted, isTrue);
      expect(completedInfo.state, TripProgressState.completed);

      // Active live trip
      final activeLoc = BusLiveLocation(
        vehicleNumber: 'AP39X6803',
        oprsNo: 'CT24/4',
        serviceType: 'PALLEVELUGU',
        latitude: 13.6547,
        longitude: 78.9445,
        speed: 45.0,
        locationBearing: 90,
        locationAltitude: 0,
        locationTime: '$nowMs',
        refreshedAt: nowMs - 10000, // 10s ago
        isOnline: true,
        serviceDocId: '27092026_CT24_4_PILER',
        tripStatus: '1',
      );

      final activeInfo = TripProgressResolver.resolve(location: activeLoc);
      expect(activeInfo.isCompleted, isFalse);
      expect(activeInfo.state, TripProgressState.active);

      // Stale active trip (33006s old)
      final staleLoc = BusLiveLocation(
        vehicleNumber: 'AP39X6803',
        oprsNo: 'CT24/4',
        serviceType: 'PALLEVELUGU',
        latitude: 13.6547,
        longitude: 78.9445,
        speed: 0.0,
        locationBearing: 0,
        locationAltitude: 0,
        locationTime: '${nowMs - 33006000}',
        refreshedAt: nowMs - 33006000,
        isOnline: true,
        serviceDocId: '27092026_CT24_4_PILER',
        tripStatus: '1',
      );

      final staleInfo = TripProgressResolver.resolve(location: staleLoc);
      expect(staleInfo.isCompleted, isFalse);
      expect(staleInfo.state, TripProgressState.staleActive);
      expect(staleInfo.isStale, isTrue);
    });
  });

  group('PHASE 4E — Widget & Render Verification Tests', () {
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final mockStops = [
      const ApsrtcRouteStop(
        stationId: '2821',
        placeName: 'CHITTOOR',
        sequenceNo: 1,
        actualDeparture: '08:30 AM',
      ),
      const ApsrtcRouteStop(
        stationId: '1668649828715',
        placeName: 'BANDA PALLI',
        sequenceNo: 2,
        actualDeparture: '08:52 AM',
      ),
      const ApsrtcRouteStop(
        stationId: '1663562995920',
        placeName: 'RANGAMPET',
        sequenceNo: 3,
        isSkipped: true,
      ),
      const ApsrtcRouteStop(
        stationId: '1457681389736',
        placeName: 'PATURU',
        sequenceNo: 4,
        actualArrival: '09:15 AM',
      ),
      const ApsrtcRouteStop(
        stationId: '11821',
        placeName: 'PILER',
        sequenceNo: 5,
        scheduledArrival: '10:30 AM',
      ),
    ];

    final segment = ApsrtcRouteSegmentResult(
      serviceDocId: '27092026_CT24_4_PILER',
      fullRouteStops: mockStops,
      visibleSegmentStops: mockStops,
      intermediateStops: mockStops.sublist(1, 4),
      viaSummary: 'Via BANDA PALLI, RANGAMPET, PATURU',
      fromIndex: 0,
      toIndex: 4,
      isValidSegment: true,
      isDirectService: false,
    );

    testWidgets(
      'Completed trip has ZERO current stops and shows TRIP COMPLETED header',
      (tester) async {
        final completedLoc = BusLiveLocation(
          vehicleNumber: 'AP39X6803',
          oprsNo: 'CT24/4',
          serviceType: 'PALLEVELUGU',
          latitude: 13.6547,
          longitude: 78.9445,
          speed: 0.0,
          locationBearing: 0,
          locationAltitude: 0,
          locationTime: '$nowMs',
          refreshedAt: nowMs - 33006000,
          isOnline: true,
          serviceDocId: '27092026_CT24_4_PILER',
          tripStatus: '2',
          serviceEndedTimeStamp: nowMs - 33006000,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: LiveBusScreen(
              serviceDocId: '27092026_CT24_4_PILER',
              service: MockLiveService(completedLoc),
              routeStopsService: MockRouteStopsService(segment),
              pollInterval: const Duration(hours: 24),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('TRIP COMPLETED'), findsOneWidget);
        expect(find.text('Current stop'), findsNothing);
        expect(find.text('33006s ago'), findsNothing);

        // Distinct per-stop times:
        expect(find.text('Departed 08:30 AM'), findsOneWidget);
        expect(find.text('Departed 08:52 AM'), findsOneWidget);
        expect(find.text('Skipped'), findsOneWidget);
        expect(find.text('Completed'), findsOneWidget);
      },
    );

    testWidgets(
      'Stale active trip shows LAST KNOWN stop and no raw telemetry seconds in stops',
      (tester) async {
        final staleLoc = BusLiveLocation(
          vehicleNumber: 'AP39X6803',
          oprsNo: 'CT24/4',
          serviceType: 'PALLEVELUGU',
          latitude: 13.6547,
          longitude: 78.9445,
          speed: 0.0,
          locationBearing: 0,
          locationAltitude: 0,
          locationTime: '${nowMs - 33006000}',
          refreshedAt: nowMs - 33006000,
          isOnline: true,
          serviceDocId: '27092026_CT24_4_PILER',
          tripStatus: '1',
          currentSeqNo: 4,
          currentBoardingPoint: '1457681389736',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: LiveBusScreen(
              serviceDocId: '27092026_CT24_4_PILER',
              service: MockLiveService(staleLoc),
              routeStopsService: MockRouteStopsService(segment),
              pollInterval: const Duration(hours: 24),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Route Timeline'), findsOneWidget);
        expect(find.text('Current stop'), findsNothing);
        expect(find.text('Arrived 09:15 AM'), findsOneWidget);
        expect(find.text('33006s ago'), findsNothing);
        expect(find.text('Telemetry'), findsOneWidget);
        expect(find.text('9h 10m ago'), findsOneWidget);
      },
    );

    testWidgets(
      'Active live trip has maximum one CURRENT stop with independent per-stop times',
      (tester) async {
        final activeLoc = BusLiveLocation(
          vehicleNumber: 'AP39X6803',
          oprsNo: 'CT24/4',
          serviceType: 'PALLEVELUGU',
          latitude: 13.6547,
          longitude: 78.9445,
          speed: 35.0,
          locationBearing: 45,
          locationAltitude: 0,
          locationTime: '$nowMs',
          refreshedAt: nowMs - 15000,
          isOnline: true,
          serviceDocId: '27092026_CT24_4_PILER',
          tripStatus: '1',
          currentSeqNo: 4,
          currentBoardingPoint: '1457681389736',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: LiveBusScreen(
              serviceDocId: '27092026_CT24_4_PILER',
              service: MockLiveService(activeLoc),
              routeStopsService: MockRouteStopsService(segment),
              pollInterval: const Duration(hours: 24),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Arrived 09:15 AM'), findsOneWidget);
        expect(find.text('Departed 08:30 AM'), findsOneWidget);
        expect(find.text('Departed 08:52 AM'), findsOneWidget);
        expect(find.text('Skipped'), findsOneWidget);
        expect(find.text('Scheduled 10:30 AM'), findsOneWidget);
      },
    );

    testWidgets(
      'No RenderFlex overflow on 360px wide screen with text scale 1.3',
      (tester) async {
        final activeLoc = BusLiveLocation(
          vehicleNumber: 'AP39X6803',
          oprsNo: 'CT24/4',
          serviceType: 'PALLEVELUGU',
          latitude: 13.6547,
          longitude: 78.9445,
          speed: 35.0,
          locationBearing: 45,
          locationAltitude: 0,
          locationTime: '$nowMs',
          refreshedAt: nowMs - 15000,
          isOnline: true,
          serviceDocId: '27092026_CT24_4_PILER',
          tripStatus: '1',
          currentSeqNo: 4,
          currentBoardingPoint: '1457681389736',
        );

        final originalOnError = FlutterError.onError;
        final flutterErrors = <FlutterErrorDetails>[];

        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;

        try {
          FlutterError.onError = (FlutterErrorDetails details) {
            flutterErrors.add(details);
          };

          await tester.pumpWidget(
            MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 800),
                textScaler: TextScaler.linear(1.3),
              ),
              child: MaterialApp(
                home: LiveBusScreen(
                  serviceDocId: '27092026_CT24_4_PILER',
                  service: MockLiveService(activeLoc),
                  routeStopsService: MockRouteStopsService(segment),
                  pollInterval: const Duration(hours: 24),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump();
        } finally {
          FlutterError.onError = originalOnError;
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }

        final overflowErrors = flutterErrors.where((details) {
          final text = details.exceptionAsString();
          return text.contains('RenderFlex') || text.contains('overflowed by');
        }).toList();

        expect(
          overflowErrors,
          isEmpty,
          reason: overflowErrors.map((e) => e.exceptionAsString()).join('\n'),
        );
      },
    );
  });
}
