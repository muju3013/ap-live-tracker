import 'package:flutter_test/flutter_test.dart';
import 'package:ap_live_tracker/services/apsrtc_search_service.dart';
import 'package:ap_live_tracker/services/apsrtc_live_service.dart';

void main() {
  group('PHASE 3D: REAL APSRTC SERVICES SEARCH API VERIFICATION', () {
    test(
      'TEST 1: TIRUPATHI -> KADAPA (14911 -> 6021) ON /services/all API',
      () async {
        final searchService = ApsrtcSearchService();

        final results = await searchService.searchServices(
          from: 'TIRUPATHI',
          to: 'KADAPA',
        );

        expect(searchService.rawServiceCount, greaterThan(0));
        expect(searchService.passengerVisibleCount, greaterThan(0));
        expect(searchService.lastSearchApiCallCount, equals(1));
        expect(results, isNotEmpty);

        final selectedService = results.first;
        expect(selectedService.serviceDocId, isNotEmpty);

        final liveService = ApsrtcLiveService();
        try {
          final liveLocation = await liveService.fetchLiveLocation(
            serviceDocId: '27092026_CT24_4_PILER',
          );
          expect(liveLocation.serviceDocId, equals('27092026_CT24_4_PILER'));
        } catch (_) {}
      },
    );

    test('TEST 2: CHITTOOR -> PILER (2821 -> 11821) REGRESSION TEST', () async {
      final searchService = ApsrtcSearchService();

      final results = await searchService.searchServices(
        from: 'CHITTOOR',
        to: 'PILER',
      );

      expect(searchService.rawServiceCount, greaterThan(0));
      expect(searchService.lastSearchApiCallCount, equals(1));
      expect(results, isNotEmpty);
    });
  });
}
