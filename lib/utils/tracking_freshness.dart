import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

enum FreshnessStatus {
  live, // 0 - 30 seconds
  delayed, // 31 - 120 seconds
  stale, // > 120 seconds
  trackingUnavailable, // isOnline == false or missing timestamp
}

class FreshnessClassification {
  final FreshnessStatus status;
  final String statusText;
  final String label;
  final int ageInSeconds;
  final Color color;
  final IconData icon;

  const FreshnessClassification({
    required this.status,
    required this.statusText,
    required this.label,
    required this.ageInSeconds,
    required this.color,
    required this.icon,
  });

  bool get isLive => status == FreshnessStatus.live;
  bool get isDelayed => status == FreshnessStatus.delayed;
  bool get isStale => status == FreshnessStatus.stale;
  bool get isTrackingUnavailable =>
      status == FreshnessStatus.trackingUnavailable;
}

class TrackingFreshnessClassifier {
  /// Primary classifier method.
  /// Evaluates telemetry freshness using exact thresholds:
  /// - isOnline == false => TRACKING UNAVAILABLE / OFFLINE
  /// - 0..30s => LIVE
  /// - 31..120s => GPS DELAYED
  /// - > 120s => STALE / LAST SEEN
  static FreshnessClassification classify({
    required bool isOnline,
    required dynamic refreshedAt,
    String? locationTime,
    DateTime? currentTime,
  }) {
    // 1. Upstream offline signal takes precedence for tracking unavailability
    if (!isOnline) {
      return const FreshnessClassification(
        status: FreshnessStatus.trackingUnavailable,
        statusText: 'OFFLINE',
        label: 'TRACKING UNAVAILABLE',
        ageInSeconds: 0,
        color: AppColors.warning,
        icon: Icons.gps_off,
      );
    }

    // 2. Parse refreshedAt timestamp to milliseconds since epoch
    int timestampMs = _parseTimestampMs(refreshedAt);

    if (timestampMs <= 0 && locationTime != null && locationTime.isNotEmpty) {
      timestampMs = _parseTimestampMs(locationTime);
    }

    if (timestampMs <= 0) {
      return const FreshnessClassification(
        status: FreshnessStatus.trackingUnavailable,
        statusText: 'OFFLINE',
        label: 'TRACKING UNAVAILABLE',
        ageInSeconds: 0,
        color: AppColors.warning,
        icon: Icons.gps_off,
      );
    }

    // 3. Calculate age in seconds (nowUtcMilliseconds - refreshedAtMilliseconds)
    final nowMs = (currentTime ?? DateTime.now()).millisecondsSinceEpoch;
    int ageInSeconds = (nowMs - timestampMs) ~/ 1000;

    if (ageInSeconds < 0) {
      ageInSeconds = 0; // clock skew safeguard
    }

    // 4. Threshold rules:
    // 0 - 30 seconds: LIVE
    // 31 - 120 seconds: GPS DELAYED
    // > 120 seconds: STALE
    if (ageInSeconds <= 30) {
      return FreshnessClassification(
        status: FreshnessStatus.live,
        statusText: 'LIVE',
        label: 'LIVE • Updated ${ageInSeconds}s ago',
        ageInSeconds: ageInSeconds,
        color: AppColors.successLive,
        icon: Icons.sensors,
      );
    } else if (ageInSeconds <= 120) {
      return FreshnessClassification(
        status: FreshnessStatus.delayed,
        statusText: 'GPS DELAYED',
        label: 'GPS DELAYED • Updated ${ageInSeconds}s ago',
        ageInSeconds: ageInSeconds,
        color: AppColors.warning,
        icon: Icons.access_time,
      );
    } else {
      final formattedAge = formatAge(ageInSeconds);
      return FreshnessClassification(
        status: FreshnessStatus.stale,
        statusText: 'STALE',
        label: 'LAST SEEN • $formattedAge',
        ageInSeconds: ageInSeconds,
        color: AppColors.secondaryText,
        icon: Icons.history,
      );
    }
  }

  static int _parseTimestampMs(dynamic val) {
    if (val == null) return 0;
    int raw = 0;
    if (val is num) {
      raw = val.toInt();
    } else if (val is String) {
      raw = int.tryParse(val) ?? (double.tryParse(val)?.toInt() ?? 0);
    }

    if (raw <= 0) return 0;

    // Standard epoch milliseconds in 2026 is ~1.79 trillion (13 digits).
    // Epoch seconds is ~1.79 billion (10 digits).
    if (raw < 10000000000) {
      return raw * 1000;
    }
    return raw;
  }

  /// Formats raw seconds into human-readable duration (e.g. 12 sec ago, 3 min ago, 9h 10m ago).
  static String formatAge(int seconds) {
    if (seconds < 60) {
      return '$seconds sec ago';
    } else if (seconds < 3600) {
      final mins = seconds ~/ 60;
      return '$mins min ago';
    } else {
      final hours = seconds ~/ 3600;
      final mins = (seconds % 3600) ~/ 60;
      if (mins == 0) return '${hours}h ago';
      return '${hours}h ${mins}m ago';
    }
  }
}
