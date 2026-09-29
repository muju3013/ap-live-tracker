import 'package:flutter_test/flutter_test.dart';
import 'package:ap_live_tracker/models/bus_live_location.dart';

void main() {
  group('BusLiveLocation.fromFirestoreJson', () {
    test('parses real Firestore REST response correctly', () {
      final json = {
        "name": "projects/apsrtc-uts-prod/databases/(default)/documents/trackingDetailsV2/27092026_CT24_4_PILER",
        "fields": {
          "depotName": {"stringValue": "PILER"},
          "speed": {"stringValue": "15.5"},
          "locationBearing": {"doubleValue": 196.67},
          "vehicleNumber": {"stringValue": "AP39X6803"},
          "oprsNo": {"stringValue": "CT24/4"},
          "locationAltitude": {"doubleValue": 500.8},
          "serviceDocId": {"stringValue": "27092026_CT24_4_PILER"},
          "latitude": {"doubleValue": 13.6543016},
          "refreshedAt": {"integerValue": "1790500196640"},
          "serviceType": {"stringValue": "PALLEVELUGU"},
          "longitude": {"doubleValue": 78.944205},
          "isOnline": {"stringValue": "1"},
          "locationTime": {"stringValue": "1790500196640"},
        },
      };

      final busLocation = BusLiveLocation.fromFirestoreJson(json);

      expect(busLocation.vehicleNumber, equals('AP39X6803'));
      expect(busLocation.oprsNo, equals('CT24/4'));
      expect(busLocation.serviceType, equals('PALLEVELUGU'));
      expect(busLocation.latitude, equals(13.6543016));
      expect(busLocation.longitude, equals(78.944205));
      expect(busLocation.speed, equals(15.5));
      expect(busLocation.locationBearing, equals(196.67));
      expect(busLocation.locationAltitude, equals(500.8));
      expect(busLocation.refreshedAt, equals(1790500196640));
      expect(busLocation.isOnline, isTrue);
      expect(busLocation.serviceDocId, equals('27092026_CT24_4_PILER'));
    });

    test('calculates freshness status correctly based on refreshedAt age', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final liveLocation = BusLiveLocation.fromFirestoreJson({
        "fields": {
          "refreshedAt": {"integerValue": "${nowMs - 10000}"}, // 10s ago
          "isOnline": {"stringValue": "1"},
        },
      });
      expect(liveLocation.getFreshnessStatus(), equals(FreshnessStatus.live));

      final delayedLocation = BusLiveLocation.fromFirestoreJson({
        "fields": {
          "refreshedAt": {"integerValue": "${nowMs - 60000}"}, // 60s ago
          "isOnline": {"stringValue": "1"},
        },
      });
      expect(
        delayedLocation.getFreshnessStatus(),
        equals(FreshnessStatus.delayed),
      );

      final staleLocation = BusLiveLocation.fromFirestoreJson({
        "fields": {
          "refreshedAt": {"integerValue": "${nowMs - 150000}"}, // 150s ago
          "isOnline": {"stringValue": "1"},
        },
      });
      expect(staleLocation.getFreshnessStatus(), equals(FreshnessStatus.stale));
    });
  });

  group('TrackingFreshnessClassifier Required Phase 4C-FIX Cases', () {
    final now = DateTime(2026, 9, 27, 17, 47, 0);

    test('refreshedAt = now - 10 sec => LIVE', () {
      final refreshedAt = now
          .subtract(const Duration(seconds: 10))
          .millisecondsSinceEpoch;
      final classification = TrackingFreshnessClassifier.classify(
        isOnline: true,
        refreshedAt: refreshedAt,
        currentTime: now,
      );

      expect(classification.status, equals(FreshnessStatus.live));
      expect(classification.statusText, equals('LIVE'));
      expect(classification.label, contains('LIVE • Updated 10s ago'));
    });

    test('refreshedAt = now - 60 sec => GPS DELAYED', () {
      final refreshedAt = now
          .subtract(const Duration(seconds: 60))
          .millisecondsSinceEpoch;
      final classification = TrackingFreshnessClassifier.classify(
        isOnline: true,
        refreshedAt: refreshedAt,
        currentTime: now,
      );

      expect(classification.status, equals(FreshnessStatus.delayed));
      expect(classification.statusText, equals('GPS DELAYED'));
      expect(classification.label, contains('GPS DELAYED • Updated 60s ago'));
    });

    test('refreshedAt = now - 121 sec => STALE', () {
      final refreshedAt = now
          .subtract(const Duration(seconds: 121))
          .millisecondsSinceEpoch;
      final classification = TrackingFreshnessClassifier.classify(
        isOnline: true,
        refreshedAt: refreshedAt,
        currentTime: now,
      );

      expect(classification.status, equals(FreshnessStatus.stale));
      expect(classification.statusText, equals('STALE'));
      expect(classification.label, contains('LAST SEEN'));
    });

    test('refreshedAt = now - 3 hours => STALE', () {
      final refreshedAt = now
          .subtract(const Duration(hours: 3))
          .millisecondsSinceEpoch;
      final classification = TrackingFreshnessClassifier.classify(
        isOnline: true,
        refreshedAt: refreshedAt,
        currentTime: now,
      );

      expect(classification.status, equals(FreshnessStatus.stale));
      expect(classification.statusText, equals('STALE'));
      expect(classification.label, contains('LAST SEEN • 3h ago'));
    });

    test(
      'isOnline == 1 but refreshedAt = now - 3 hours => STALE, NOT LIVE',
      () {
        final refreshedAt = now
            .subtract(const Duration(hours: 3))
            .millisecondsSinceEpoch;
        final classification = TrackingFreshnessClassifier.classify(
          isOnline: true,
          refreshedAt: refreshedAt,
          currentTime: now,
        );

        expect(classification.status, isNot(equals(FreshnessStatus.live)));
        expect(classification.status, equals(FreshnessStatus.stale));
        expect(classification.statusText, equals('STALE'));
      },
    );

    test('isOnline == 0 => OFFLINE / TRACKING UNAVAILABLE', () {
      final refreshedAt = now
          .subtract(const Duration(seconds: 5))
          .millisecondsSinceEpoch;
      final classification = TrackingFreshnessClassifier.classify(
        isOnline: false,
        refreshedAt: refreshedAt,
        currentTime: now,
      );

      expect(
        classification.status,
        equals(FreshnessStatus.trackingUnavailable),
      );
      expect(classification.statusText, equals('OFFLINE'));
      expect(classification.label, equals('TRACKING UNAVAILABLE'));
    });
  });
}
