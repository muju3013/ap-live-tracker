import 'dart:convert';
import 'dart:io';

import 'package:ap_live_tracker/models/apsrtc_service_search_result.dart';
import 'package:ap_live_tracker/services/apsrtc_place_repository.dart';
import 'package:ap_live_tracker/services/apsrtc_search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApsrtcPlaceRepository repository;
  late String rawPlacesContent;

  setUpAll(() {
    final encFile = File('assets/data/apsrtc_places.enc');
    final jsonFile = File('assets/data/apsrtc_places.json');

    if (encFile.existsSync()) {
      rawPlacesContent = encFile.readAsStringSync();
    } else if (jsonFile.existsSync()) {
      rawPlacesContent = jsonFile.readAsStringSync();
    } else {
      fail('Place dataset asset file not found!');
    }

    repository = ApsrtcPlaceRepository();
    repository.loadPlacesFromRaw(rawPlacesContent);
  });

  group('PHASE 3E-CORRECTION — REAL APSRTC SOURCE-OF-TRUTH VERIFICATION', () {
    test('1. Dataset Count Assertions (12,443 miniServicePlaces)', () {
      expect(repository.totalPlacesLoaded, equals(12443));
      expect(repository.uniquePlaceIdsCount, equals(12443));

      // Exact KALLURU count == 5
      final kalluruResults = repository
          .searchPlaces('KALLURU', limit: 100)
          .where((s) => s.placeName == 'KALLURU')
          .toList();
      expect(kalluruResults.length, equals(5));
    });

    test('2. Specific Station Canonical Data Verification', () {
      // Pulicherla KALLURU verification
      final pulicherlaKalluru = repository.getPlaceById('224342');
      expect(pulicherlaKalluru, isNotNull);
      expect(pulicherlaKalluru!.placeId, equals('224342'));
      expect(pulicherlaKalluru.linkPlaceId, equals('224342'));
      expect(pulicherlaKalluru.placeName, equals('KALLURU'));
      expect(pulicherlaKalluru.pinCode, equals('517113'));
      expect(pulicherlaKalluru.mandalName, equals('PULICHERLA'));
      expect(pulicherlaKalluru.latitude, closeTo(13.558327, 0.0001));
      expect(pulicherlaKalluru.longitude, closeTo(79.000400, 0.0001));

      // TIRUPATHI
      final tirupathi = repository.getPlaceById('14911');
      expect(tirupathi, isNotNull);
      expect(tirupathi!.placeName, equals('TIRUPATHI'));
      expect(tirupathi.mandalName, equals('TIRUPATI URBAN'));

      // KADAPA
      final kadapa = repository.getPlaceById('6021');
      expect(kadapa, isNotNull);
      expect(kadapa!.placeName, equals('KADAPA'));
      expect(kadapa.mandalName, equals('KADAPA'));

      // CHITTOOR
      final chittoor = repository.getPlaceById('2821');
      expect(chittoor, isNotNull);
      expect(chittoor!.placeName, equals('CHITTOOR'));
      expect(chittoor.mandalName, equals('CHITTOOR'));

      // PILER
      final piler = repository.getPlaceById('11821');
      expect(piler, isNotNull);
      expect(piler!.placeName, equals('PILER'));
      expect(piler.mandalName, equals('PILER'));

      // DAMALCHERVU
      final damalchervu = repository.getPlaceById('3081');
      expect(damalchervu, isNotNull);
      expect(damalchervu!.placeName, equals('DAMALCHERVU'));
      expect(damalchervu.mandalName, equals('PAKALA'));
    });

    test('3. Autocomplete Tests (TIRU, KADA, KALLU)', () {
      final tiru = repository.searchPlaces('TIRU', limit: 30);
      expect(tiru, isNotEmpty);
      expect(tiru.any((s) => s.placeId == '14911'), isTrue);

      final kada = repository.searchPlaces('KADA', limit: 30);
      expect(kada, isNotEmpty);
      expect(kada.any((s) => s.placeId == '6021'), isTrue);

      final kallu = repository.searchPlaces('KALLU', limit: 30);
      expect(kallu, isNotEmpty);
      final kalluExact = kallu.where((s) => s.placeName == 'KALLURU').toList();
      expect(kalluExact.length, equals(5));

      // Confirm all 5 KALLURU options are distinguishable via mandal/pincode
      for (final k in kalluExact) {
        expect(k.displaySubtitle, isNotEmpty);
        expect(k.displaySubtitle.contains('null'), isFalse);
      }
    });

    test('4. TIRUPATHI -> KADAPA /services/all Regression Test', () async {
      int apiCallCount = 0;
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/services/all')) {
          apiCallCount++;
          final body = jsonDecode(request.body);
          expect(body['sourcePlaceId'], equals(14911));
          expect(body['destinationPlaceId'], equals(6021));

          final mockResponse = {
            "status": "success",
            "data": [
              {
                "oprsNo": "64234",
                "serviceId": "CHN4",
                "arrivalTime": "17:45",
                "departureDay": "27-Sep-2026",
                "arrivalDay": "27-Sep-2026",
                "depotName": "CHENNAI",
                "tripNo": "2",
                "journeyDate": "27-Sep-2026",
                "departureTimeNum": 57300,
                "serviceType": "EXPRESS",
                "serviceStartTime": "15:55",
                "serviceEndTime": "17:45",
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
          return http.Response(
            jsonEncode(mockResponse),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 444);
      });

      final searchService = ApsrtcSearchService(
        client: mockClient,
        placeRepository: repository,
      );

      final from = repository.getPlaceById('14911')!;
      final to = repository.getPlaceById('6021')!;

      final results = await searchService.searchServices(
        fromStation: from,
        toStation: to,
      );

      expect(apiCallCount, equals(1));
      expect(results.length, equals(1));
      expect(
        results.first.serviceDocId,
        equals('27092026_CHN4_2_JAMMALAMADUGU'),
      );
      expect(results.first.isTrackingAvailable, isTrue);
      expect(results.first.status, equals(BusServiceStatus.upcoming));
    });
  });
}
