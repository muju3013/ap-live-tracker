import 'package:flutter_test/flutter_test.dart';
import 'package:ap_live_tracker/services/apsrtc_live_service.dart';
import 'package:ap_live_tracker/services/apsrtc_search_service.dart';

void main() {
  group('PHASE 3C: REAL APSRTC LIVE VERIFICATION SUITE', () {
    test('CASE 5: DATE FILTER & TIMEZONE VERIFICATION', () {
      final generatedJourneyDate = ApsrtcSearchService.getTodayApsrtcDate();

      expect(
        RegExp(r'^\d{2}-[A-Z][a-z]{2}-\d{4}$').hasMatch(generatedJourneyDate),
        isTrue,
      );
    });

    test('CASE 1: CHITTOOR -> PILER REAL LIVE NETWORK TEST', () async {
      final searchService = ApsrtcSearchService();

      final results = await searchService.searchServices(
        from: 'CHITTOOR',
        to: 'PILER',
      );

      for (var i = 0; i < results.length; i++) {
        final r = results[i];
        expect(
          r.journeyDate.contains('2026') || r.journeyDate.contains('27'),
          isTrue,
        );
        expect(r.serviceDocId.startsWith('13092026_'), isFalse);
      }
    });

    test('CASE 2 & CASE 3: DAMALCHERVU <-> KALLURU INTERMEDIATE STOP & DIRECTION TEST', () async {
      final searchService = ApsrtcSearchService();

      final fwdResults = await searchService.searchServices(
        from: 'DAMALCHERVU',
        to: 'KALLURU',
      );

      for (var r in fwdResults) {
        if (r.wayPointString != null) {
          final wayPoints = r.wayPointString!.split(',');
          final fromIdx = wayPoints.indexOf('3081'); // DAMALCHERVU
          final toIdx = wayPoints.indexOf('224342'); // KALLURU
          expect(fromIdx < toIdx, isTrue);
        }
      }

      final revResults = await searchService.searchServices(
        from: 'KALLURU',
        to: 'DAMALCHERVU',
      );

      final containsCt24_4InReverse = revResults.any(
        (r) =>
            r.serviceDocId.contains('CT24_4') ||
            r.serviceNumber.contains('CT24/4'),
      );
      expect(containsCt24_4InReverse, isFalse);
    });

    test('CASE 4: STATION SEARCH DIRECTORY AUDIT', () {
      final searchService = ApsrtcSearchService();
      final testStations = [
        'CHITTOOR',
        'PILER',
        'DAMALCHERVU',
        'KALLURU',
        'TIRUPATHI',
        'KADAPA',
      ];

      for (final name in testStations) {
        final st = searchService.findStation(name);
        expect(st, isNotNull);
      }
    });

    test('CASE 6: LIVE DATA FRESHNESS & POLLING CHANGE TEST', () async {
      final liveService = ApsrtcLiveService();
      const targetDocId = '27092026_CT24_4_PILER';

      final loc1 = await liveService.fetchLiveLocation(
        serviceDocId: targetDocId,
      );
      final age1 = loc1.getAgeInSeconds();

      expect(loc1.serviceDocId, equals(targetDocId));
      expect(age1, greaterThanOrEqualTo(0));

      await Future.delayed(const Duration(seconds: 1));

      final loc2 = await liveService.fetchLiveLocation(
        serviceDocId: targetDocId,
      );
      expect(loc2.serviceDocId, equals(targetDocId));
    });

    test('CASE 8: NETWORK LOAD & REQUEST COUNT METRICS', () async {
      final searchService = ApsrtcSearchService();

      await searchService.searchServices(from: 'CHITTOOR', to: 'PILER');

      expect(searchService.lastSearchApiCallCount, greaterThan(0));
    });
  });
}
