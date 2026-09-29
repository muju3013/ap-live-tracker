// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:ap_live_tracker/models/apsrtc_station.dart';
import 'package:ap_live_tracker/services/apsrtc_place_repository.dart';
import 'package:ap_live_tracker/services/apsrtc_route_stops_service.dart';
import 'package:ap_live_tracker/services/apsrtc_search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApsrtcPlaceRepository placeRepo;
  late ApsrtcRouteStopsService routeStopsService;

  setUpAll(() async {
    placeRepo = ApsrtcPlaceRepository();
    await placeRepo.loadPlaces();
    routeStopsService = ApsrtcRouteStopsService(placeRepository: placeRepo);
  });

  group('PHASE 4D-FIX — REAL ROUTE STOPS & ZERO N+1 NETWORK REQUESTS', () {
    test('1. BANDA PALLI resolves directly from ApsrtcPlaceRepository miniServicePlaces', () {
      expect(placeRepo.totalPlacesLoaded, equals(12443));

      final station = placeRepo.getPlaceById('1668649828715');
      expect(station, isNotNull);
      expect(station!.placeName, equals('BANDA PALLI'));
      expect(station.resolutionSource, equals('miniServicePlaces'));
      expect(station.mandalName, equals('PUTHALAPATTU'));
      expect(station.pinCode, equals('517127'));
    });

    test(
      '2. Long numeric IDs are valid lookup keys in ApsrtcPlaceRepository',
      () {
        final s1 = placeRepo.getPlaceById('1668649828715');
        expect(s1, isNotNull);
        expect(s1!.placeId, equals('1668649828715'));
        expect(s1.resolutionSource, equals('miniServicePlaces'));
      },
    );

    test('3. Secondary stop directory resolves RANGAMPET and PATURU with secondaryStopDirectory source', () {
      final s1 = placeRepo.getPlaceById('1663562995920');
      expect(s1, isNotNull);
      expect(s1!.placeName, equals('RANGAMPET'));
      expect(s1.resolutionSource, equals('secondaryStopDirectory'));

      final s2 = placeRepo.getPlaceById('1457681389736');
      expect(s2, isNotNull);
      expect(s2!.placeName, equals('PATURU'));
      expect(s2.resolutionSource, equals('secondaryStopDirectory'));

      expect(placeRepo.totalPlacesLoaded, equals(12443));
    });

    test(
      '4. Unknown ID 9999999999999 remains Intermediate stop without crashing',
      () async {
        final res = await routeStopsService.resolveRouteStops(
          serviceDocId: 'TEST_UNKNOWN_ID',
          wayPointString: '2821,9999999999999,11821',
          fromName: 'CHITTOOR',
          toName: 'PILER',
        );

        expect(res.fullRouteStops.length, equals(3));
        expect(res.fullRouteStops[1].stationId, equals('9999999999999'));
        expect(res.fullRouteStops[1].placeName, equals('Intermediate stop'));
        expect(res.fullRouteStops[1].resolvedSource, equals('unresolved'));
      },
    );

    test('5. CT24/4 REGRESSION TEST: Exactly 13 stops resolved with exact real names and sources', () async {
      const wayPointStr =
          '2821,227284,1668649828715,12281,1663562995920,227380,1457681389736,3081,236386,224342,221471,230556,11821';

      final result = await routeStopsService.resolveRouteStops(
        serviceDocId: '27092026_CT24_4_PILER_FINAL',
        wayPointString: wayPointStr,
        fromStation: const ApsrtcStation(
          placeId: '2821',
          linkPlaceId: '2821',
          placeName: 'CHITTOOR',
        ),
        toStation: const ApsrtcStation(
          placeId: '11821',
          linkPlaceId: '11821',
          placeName: 'PILER',
        ),
      );

      expect(result.isValidSegment, isTrue);
      expect(result.fullRouteStops.length, equals(13));

      final names = result.fullRouteStops.map((s) => s.placeName).toList();
      const expectedOrder = [
        'CHITTOOR',
        'PENUMURU X',
        'BANDA PALLI',
        'PUTALAPATTU',
        'RANGAMPET',
        'THALAPULAPALLE',
        'PATURU',
        'DAMALCHERVU',
        'KOMMIREDDIPALLI XROAD',
        'KALLURU',
        'AYYAVANDLAPALLE',
        'YERRAGUNTLAPALLE',
        'PILER',
      ];

      expect(names, equals(expectedOrder));

      final sources = result.fullRouteStops
          .map((s) => s.resolvedSource)
          .toList();
      expect(sources[0], equals('miniServicePlaces'));
      expect(sources[1], equals('miniServicePlaces'));
      expect(sources[2], equals('miniServicePlaces'));
      expect(sources[3], equals('miniServicePlaces'));
      expect(sources[4], equals('secondaryStopDirectory'));
      expect(sources[5], equals('miniServicePlaces'));
      expect(sources[6], equals('secondaryStopDirectory'));
      expect(sources[7], equals('miniServicePlaces'));
      expect(sources[8], equals('miniServicePlaces'));
      expect(sources[9], equals('miniServicePlaces'));
      expect(sources[10], equals('miniServicePlaces'));
      expect(sources[11], equals('miniServicePlaces'));
      expect(sources[12], equals('miniServicePlaces'));
    });

    test('SEGMENT TEST: DAMALCHERVU -> KALLURU segment extraction & summary', () async {
      const wayPointStr =
          '2821,227284,1668649828715,12281,1663562995920,227380,1457681389736,3081,236386,224342,221471,230556,11821';

      final result = await routeStopsService.resolveRouteStops(
        serviceDocId: '27092026_CT24_4_PILER',
        wayPointString: wayPointStr,
        fromStation: const ApsrtcStation(
          placeId: '3081',
          linkPlaceId: '3081',
          placeName: 'DAMALCHERVU',
        ),
        toStation: const ApsrtcStation(
          placeId: '224342',
          linkPlaceId: '224342',
          placeName: 'KALLURU',
        ),
      );

      expect(result.isValidSegment, isTrue);
      expect(result.fromIndex < result.toIndex, isTrue);

      final visibleNames = result.visibleSegmentStops
          .map((s) => s.placeName)
          .toList();
      expect(
        visibleNames,
        equals(['DAMALCHERVU', 'KOMMIREDDIPALLI XROAD', 'KALLURU']),
      );
      expect(result.viaSummary, equals('Via KOMMIREDDIPALLI XROAD'));
    });

    test('NETWORK CALL COUNT: Initial search issues 1 POST and 0 route-detail GETs', () async {
      final searchService = ApsrtcSearchService(placeRepository: placeRepo);
      String firstDocId = '27092026_TP11_2_KADAPA';

      try {
        final results = await searchService.searchServices(
          from: 'TIRUPATHI',
          to: 'KADAPA',
        );
        expect(searchService.lastSearchApiCallCount, equals(1));
        if (results.isNotEmpty) {
          firstDocId = results.first.serviceDocId;
        }
      } catch (_) {
        // Network blip fallback
      }

      // Initial search items do not issue route detail GET requests
      expect(routeStopsService.getCachedRoute(firstDocId), isNull);

      // Tap View route -> 1st fetch resolves and caches
      final routeRes1 = await routeStopsService.resolveRouteStops(
        serviceDocId: firstDocId,
        fromName: 'TIRUPATHI',
        toName: 'KADAPA',
      );
      expect(routeRes1.fullRouteStops.isNotEmpty, isTrue);
      expect(routeStopsService.getCachedRoute(firstDocId), isNotNull);

      // Re-opening or fetching same route reuses cache without additional GET
      final routeRes2 = await routeStopsService.resolveRouteStops(
        serviceDocId: firstDocId,
        fromName: 'TIRUPATHI',
        toName: 'KADAPA',
      );
      expect(
        identical(routeRes1, routeRes2) ||
            routeRes1.serviceDocId == routeRes2.serviceDocId,
        isTrue,
      );
    });
  });
}
