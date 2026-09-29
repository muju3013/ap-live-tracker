import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ap_live_tracker/services/apsrtc_live_service.dart';

void main() {
  group('ApsrtcLiveService', () {
    test(
      'fetchLiveLocation returns BusLiveLocation for dynamic serviceDocId',
      () async {
        final mockResponse = {
          "fields": {
            "vehicleNumber": {"stringValue": "AP39X6803"},
            "oprsNo": {"stringValue": "CT24/4"},
            "serviceType": {"stringValue": "PALLEVELUGU"},
            "latitude": {"doubleValue": 13.6543016},
            "longitude": {"doubleValue": 78.944205},
            "speed": {"stringValue": "0.0"},
            "locationBearing": {"doubleValue": 104.66},
            "locationAltitude": {"doubleValue": 502.1},
            "locationTime": {"stringValue": "1790500001443"},
            "refreshedAt": {"integerValue": "1790500001443"},
            "isOnline": {"stringValue": "1"},
            "serviceDocId": {"stringValue": "27092026_CT24_4_PILER"},
          },
        };

        String? requestedUrl;
        final client = MockClient((request) async {
          requestedUrl = request.url.toString();
          return http.Response(jsonEncode(mockResponse), 200);
        });

        final service = ApsrtcLiveService(client: client);
        final result = await service.fetchLiveLocation(
          serviceDocId: '27092026_CT24_4_PILER',
        );

        expect(requestedUrl, contains('27092026_CT24_4_PILER'));
        expect(result.vehicleNumber, equals('AP39X6803'));
        expect(result.oprsNo, equals('CT24/4'));
        expect(result.latitude, equals(13.6543016));
        expect(result.longitude, equals(78.944205));
      },
    );

    test('fetchLiveLocation throws HttpException on HTTP error', () async {
      final client = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final service = ApsrtcLiveService(client: client);

      expect(
        () => service.fetchLiveLocation(serviceDocId: 'invalid_doc_id'),
        throwsA(isA<HttpException>()),
      );
    });
  });
}
