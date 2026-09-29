import '../utils/tracking_freshness.dart';
import 'apsrtc_vehicle_search_service.dart';

class ScoredVehicleCandidate {
  final ApsrtcVehicleSearchResult result;
  final int categoryScore;
  final bool isToday;
  final FreshnessClassification freshness;

  const ScoredVehicleCandidate({
    required this.result,
    required this.categoryScore,
    required this.isToday,
    required this.freshness,
  });
}

class ApsrtcCurrentVehicleTripResolver {
  /// Normalizes vehicle number string.
  static String normalizeVehicleNumber(String raw) {
    return raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  /// Evaluates candidates and returns the single best current active vehicle trip.
  static ApsrtcVehicleSearchResult? resolveCurrentTrip(
    List<ApsrtcVehicleSearchResult> candidates, {
    DateTime? currentTime,
  }) {
    final scored = evaluateCandidates(candidates, currentTime: currentTime);
    if (scored.isEmpty) return null;
    return scored.first.result;
  }

  /// Evaluates and ranks candidate documents by freshness, trip status, date, and timestamp.
  static List<ScoredVehicleCandidate> evaluateCandidates(
    List<ApsrtcVehicleSearchResult> candidates, {
    DateTime? currentTime,
  }) {
    if (candidates.isEmpty) return [];

    final now = currentTime ?? DateTime.now();
    final nowIst = now.toUtc().add(const Duration(hours: 5, minutes: 30));
    final todayPrefix =
        '${nowIst.day.toString().padLeft(2, '0')}${nowIst.month.toString().padLeft(2, '0')}${nowIst.year}';

    final list = candidates.map((c) {
      // Verified from production Firestore documents: tripStatus == '2' indicates COMPLETED trip
      final isCompleted = c.tripStatus == '2' || c.isAbnormalEndTrip;

      final freshness = TrackingFreshnessClassifier.classify(
        isOnline: c.isOnline,
        refreshedAt: c.refreshedAt,
        locationTime: c.locationTime,
        currentTime: now,
      );

      final isToday = c.serviceDocId.startsWith(todayPrefix);

      // Verified Category Scoring:
      // Category 3 (Score 300): Active + Today's date + Live/Delayed telemetry
      // Category 2.5 (Score 250): Active + Today's date
      // Category 2 (Score 200): Active + Historical date
      // Category 1 (Score 100): Completed trip (tripStatus == '2')
      int categoryScore = 100;
      if (!isCompleted) {
        if (isToday) {
          if (freshness.status == FreshnessStatus.live ||
              freshness.status == FreshnessStatus.delayed) {
            categoryScore = 300;
          } else {
            categoryScore = 250;
          }
        } else {
          categoryScore = 200;
        }
      }

      return ScoredVehicleCandidate(
        result: c,
        categoryScore: categoryScore,
        isToday: isToday,
        freshness: freshness,
      );
    }).toList();

    list.sort((a, b) {
      if (a.categoryScore != b.categoryScore) {
        return b.categoryScore.compareTo(a.categoryScore);
      }
      if (a.isToday != b.isToday) {
        return a.isToday ? -1 : 1;
      }
      return b.result.refreshedAt.compareTo(a.result.refreshedAt);
    });

    return list;
  }
}
