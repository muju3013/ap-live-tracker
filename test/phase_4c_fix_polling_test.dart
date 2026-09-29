// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ap_live_tracker/models/bus_live_location.dart';

void main() {
  test('Poll 27092026_CT24_4_PILER live Firestore telemetry 3 times and verify STALE freshness', () async {
    final client = HttpClient();
    const docId = '27092026_CT24_4_PILER';
    final url =
        'https://firestore.googleapis.com/v1/projects/apsrtc-uts-prod/databases/(default)/documents/trackingDetailsV2/$docId';

    print('\n==================================================');
    print('TESTING 27092026_CT24_4_PILER FRESHNESS CLASSIFICATION');
    print('Current Local Time: ${DateTime.now()}');
    print('==================================================');

    int? previousRefreshedAt;
    bool refreshedAtChanged = false;

    for (int cycle = 1; cycle <= 3; cycle++) {
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close();

      if (resp.statusCode == 200) {
        final bodyStr = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr);
        final busLoc = BusLiveLocation.fromFirestoreJson(json);
        final classification = busLoc.getFreshnessClassification();

        if (previousRefreshedAt != null &&
            previousRefreshedAt != busLoc.refreshedAt) {
          refreshedAtChanged = true;
        }
        previousRefreshedAt = busLoc.refreshedAt;

        print('Poll $cycle:');
        print('  ServiceDocId: ${busLoc.serviceDocId}');
        print('  Vehicle: ${busLoc.vehicleNumber}');
        print('  isOnline: ${busLoc.isOnline}');
        print('  refreshedAt: ${busLoc.refreshedAt}');
        print(
          '  Age: ${classification.ageInSeconds} seconds (${(classification.ageInSeconds / 60).toStringAsFixed(1)} mins)',
        );
        print('  Status Enum: ${classification.status}');
        print('  Status Text: ${classification.statusText}');
        print('  Display Label: ${classification.label}');

        // Assert that because refreshedAt was ~14:52 IST and now is ~18:22 IST (~3.5 hours old),
        // it MUST classify as STALE (not LIVE!)
        expect(classification.status, equals(FreshnessStatus.stale));
        expect(classification.statusText, equals('STALE'));
      } else {
        print('Poll $cycle: HTTP ${resp.statusCode}');
      }

      if (cycle < 3) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    print('\nSummary:');
    print('  RefreshedAt changed across polls? $refreshedAtChanged');
    expect(refreshedAtChanged, isFalse);
    client.close();
  });
}
