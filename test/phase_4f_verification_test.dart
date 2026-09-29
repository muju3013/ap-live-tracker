import 'package:ap_live_tracker/models/apsrtc_service_search_result.dart';
import 'package:ap_live_tracker/services/apsrtc_current_vehicle_trip_resolver.dart';
import 'package:ap_live_tracker/services/apsrtc_vehicle_search_service.dart';
import 'package:ap_live_tracker/widgets/bus_service_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PHASE 4F — FIX EXACT VEHICLE TRACKING & OVERFLOW AUDIT SUITE', () {
    test('1. Exact vehicle lookup with multiple historical docs returns ONE best candidate', () {
      final candidates = [
        const ApsrtcVehicleSearchResult(
          vehicleNumber: 'AP39X6803',
          serviceDocId: '24052023_CT24_1_PILER',
          oprsNo: 'CT24/1',
          serviceType: 'PALLEVELUGU',
          depotName: 'PILER',
          isOnline: false,
          refreshedAt: 1684900000000,
          locationTime: '2023-05-24 10:00:00',
          tripStatus: '2',
        ),
        const ApsrtcVehicleSearchResult(
          vehicleNumber: 'AP39X6803',
          serviceDocId: '28092026_CT24_4_PILER',
          oprsNo: 'CT24/4',
          serviceType: 'PALLEVELUGU',
          depotName: 'PILER',
          isOnline: true,
          refreshedAt: 1790500000000,
          locationTime: '2026-09-28 14:00:00',
          tripStatus: '1',
        ),
        const ApsrtcVehicleSearchResult(
          vehicleNumber: 'AP39X6803',
          serviceDocId: '27092026_CT24_2_PILER',
          oprsNo: 'CT24/2',
          serviceType: 'PALLEVELUGU',
          depotName: 'PILER',
          isOnline: false,
          refreshedAt: 1790400000000,
          locationTime: '2026-09-27 10:00:00',
          tripStatus: '2',
        ),
      ];

      final best = ApsrtcCurrentVehicleTripResolver.resolveCurrentTrip(
        candidates,
        currentTime: DateTime(2026, 9, 28, 14, 30),
      );

      expect(best, isNotNull);
      expect(best!.serviceDocId, equals('28092026_CT24_4_PILER'));
      expect(best.oprsNo, equals('CT24/4'));
    });

    test('2. Old historical services are not labeled active', () {
      final historicalCandidate = const ApsrtcVehicleSearchResult(
        vehicleNumber: 'AP39X6803',
        serviceDocId: '24052023_CT24_1_PILER',
        oprsNo: 'CT24/1',
        serviceType: 'PALLEVELUGU',
        depotName: 'PILER',
        isOnline: false,
        refreshedAt: 1684900000000,
        locationTime: '2023-05-24 10:00:00',
        tripStatus: '2',
      );

      final evaluated = ApsrtcCurrentVehicleTripResolver.evaluateCandidates([
        historicalCandidate,
      ], currentTime: DateTime(2026, 9, 28, 14, 30));

      expect(evaluated.first.categoryScore, equals(100)); // Historical score
    });

    test(
      '3. Latest refreshedAt candidate wins when trip state is otherwise equal',
      () {
        final candidates = [
          const ApsrtcVehicleSearchResult(
            vehicleNumber: 'AP39X6803',
            serviceDocId: '28092026_CT24_1_PILER',
            oprsNo: 'CT24/1',
            serviceType: 'PALLEVELUGU',
            depotName: 'PILER',
            isOnline: true,
            refreshedAt: 1790500000000,
            locationTime: '2026-09-28 10:00:00',
            tripStatus: '1',
          ),
          const ApsrtcVehicleSearchResult(
            vehicleNumber: 'AP39X6803',
            serviceDocId: '28092026_CT24_2_PILER',
            oprsNo: 'CT24/2',
            serviceType: 'PALLEVELUGU',
            depotName: 'PILER',
            isOnline: true,
            refreshedAt: 1790510000000, // Newer timestamp
            locationTime: '2026-09-28 12:00:00',
            tripStatus: '1',
          ),
        ];

        final best = ApsrtcCurrentVehicleTripResolver.resolveCurrentTrip(
          candidates,
          currentTime: DateTime(2026, 9, 28, 14, 30),
        );

        expect(best!.serviceDocId, equals('28092026_CT24_2_PILER'));
      },
    );

    testWidgets('4 & 5. Completed trip does not show TRACK LIVE button', (
      WidgetTester tester,
    ) async {
      final result = const ApsrtcServiceSearchResult(
        serviceDocId: '28092026_CT24_4_PILER',
        serviceNumber: 'CT24/4',
        source: 'CHITTOOR',
        destination: 'PILER',
        fromStop: 'CHITTOOR',
        toStop: 'PILER',
        serviceType: 'PALLEVELUGU',
        scheduledDeparture: '07:00 AM',
        scheduledArrival: '09:00 AM',
        depot: 'PILER',
        journeyDate: '28-Sep-2026',
        status: BusServiceStatus.completed,
        statusText: 'COMPLETED',
        isTrackingAvailable: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BusServiceCard(
              result: result,
              onTrackLive: () {},
              onViewDetails: () {},
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('TRACK LIVE'), findsNothing);
      expect(find.textContaining('VIEW DETAILS'), findsOneWidget);
    });

    testWidgets(
      '6, 7, 8, 9, 10, 11, 12. BusServiceCard renders without overflow at 320/360 width with long text scale and no Doc ID',
      (WidgetTester tester) async {
        final List<FlutterErrorDetails> flutterErrors = [];
        FlutterError.onError = (details) {
          flutterErrors.add(details);
        };

        final longResult = const ApsrtcServiceSearchResult(
          serviceDocId: '28092026_CT24_4_PILER_LONG_DOC_ID_INTERNAL',
          serviceNumber: 'GM02/1',
          source: 'TIRUPATHI CENTRAL BUS STATION',
          destination: 'JAMMALAMADUGU BUS DEPOT TERMINAL',
          fromStop: 'TIRUPATHI URBAN MAIN STOP',
          toStop: 'JAMMALAMADUGU TOWN STOP',
          serviceType: 'GREEN SAPTAGIRI(2+2 AC EV)',
          scheduledDeparture: '07:20 AM',
          scheduledArrival: '01:45 PM',
          depot: 'TIRUPATI URBAN DEPOT MAIN',
          journeyDate: '28-Sep-2026',
          status: BusServiceStatus.running,
          statusText: 'RUNNING',
          vehicleNumber: 'AP39X6803',
          isTrackingAvailable: true,
        );

        // Test widths: 320, 360 and TextScalers: 1.0, 1.3, 1.5
        for (final width in [320.0, 360.0]) {
          for (final scale in [1.0, 1.3, 1.5]) {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1.0;

            await tester.pumpWidget(
              MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 800),
                  textScaler: TextScaler.linear(scale),
                ),
                child: MaterialApp(
                  home: Scaffold(
                    body: SingleChildScrollView(
                      child: BusServiceCard(
                        result: longResult,
                        onTrackLive: () {},
                        onViewDetails: () {},
                      ),
                    ),
                  ),
                ),
              ),
            );

            await tester.pump();
          }
        }

        // Verify no Doc ID is visible in the rendered card
        expect(find.textContaining('Doc ID'), findsNothing);
        expect(find.textContaining('28092026_CT24_4_PILER'), findsNothing);

        // Verify no RenderFlex errors were thrown
        expect(
          flutterErrors.where(
            (e) => e.toString().contains('RenderFlex overflow'),
          ),
          isEmpty,
        );
      },
    );
  });
}
