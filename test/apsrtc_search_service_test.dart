import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ap_live_tracker/services/apsrtc_search_service.dart';

void main() {
  group('ApsrtcSearchService Phase 3D', () {
    test('getTodayApsrtcDate generates valid dd-MMM-yyyy format', () {
      final testDate = DateTime.utc(
        2026,
        9,
        27,
        10,
        0,
      ); // 10:00 UTC -> 15:30 IST
      final dateStr = ApsrtcSearchService.getTodayApsrtcDate(testDate);
      expect(dateStr, equals('27-Sep-2026'));
    });

    test(
      'searchServices performs /services/all primary search and parses results',
      () async {
        final mockServicesAllResponse = {
          "status": "success",
          "message": "Services found",
          "data": [
            {
              "oprsNo": "CT24/4",
              "serviceId": 1668648445195,
              "arrivalTime": "1515",
              "departureDay": 0,
              "arrivalDay": 0,
              "depotName": "PILER",
              "tripNo": 4,
              "journeyDate": "2026-09-27",
              "departureTimeNum": 1300,
              "serviceType": "PALLEVELUGU",
              "serviceStartTime": "01:00 PM",
              "serviceEndTime": "03:15 PM",
              "startCityPlaceId": 2821,
              "endCityPlaceId": 11821,
              "isClose": false,
              "isCancel": false,
              "isDirect": true,
              "exactMatch": true,
              "serviceDocId": "27092026_CT24_4_PILER",
              "sourceName": "CHITTOOR",
              "destinationName": "PILER",
            },
          ],
        };

        final client = MockClient((request) async {
          if (request.url.path.contains('services/all')) {
            return http.Response(jsonEncode(mockServicesAllResponse), 200);
          }
          return http.Response('Not Found', 404);
        });

        final service = ApsrtcSearchService(client: client);
        final results = await service.searchServices(
          from: 'CHITTOOR',
          to: 'PILER',
        );

        expect(results.length, equals(1));
        final item = results.first;
        expect(item.serviceDocId, equals('27092026_CT24_4_PILER'));
        expect(item.source, equals('CHITTOOR'));
        expect(item.destination, equals('PILER'));
        expect(item.serviceType, equals('PALLEVELUGU'));
        expect(item.scheduledDeparture, equals('01:00 PM'));
        expect(item.isCancel, isFalse);
      },
    );

    test('searchServices matches intermediate stops in forward direction via fallback query', () async {
      final todayDate = ApsrtcSearchService.getTodayApsrtcDate();

      final mockServicesAllResponse = {
        "status": "success",
        "data": [
          {
            "oprsNo": "CT24/4",
            "serviceId": "1668648445195",
            "arrivalTime": "1515",
            "departureDay": 0,
            "arrivalDay": 0,
            "depotName": "PILER",
            "tripNo": 4,
            "journeyDate": todayDate,
            "departureTimeNum": 1300,
            "serviceType": "PALLEVELUGU",
            "serviceStartTime": "01:00 PM",
            "serviceEndTime": "03:15 PM",
            "startCityPlaceId": 3081,
            "endCityPlaceId": 224342,
            "isClose": false,
            "isCancel": false,
            "isDirect": true,
            "exactMatch": true,
            "serviceDocId": "27092026_CT24_4_PILER",
            "sourceName": "DAMALCHERVU",
            "destinationName": "KALLURU",
          },
        ],
      };

      final client = MockClient((request) async {
        if (request.url.path.contains('services/all')) {
          return http.Response(jsonEncode(mockServicesAllResponse), 200);
        }
        return http.Response('{"status": "error", "data": []}', 404);
      });

      final service = ApsrtcSearchService(client: client);
      final results = await service.searchServices(
        from: 'DAMALCHERVU',
        to: 'KALLURU',
      );

      expect(results.length, equals(1));
      final item = results.first;
      expect(item.serviceDocId, equals('27092026_CT24_4_PILER'));
      expect(item.fromStop, equals('DAMALCHERVU'));
      expect(item.toStop, equals('KALLURU'));
    });
  });
}
