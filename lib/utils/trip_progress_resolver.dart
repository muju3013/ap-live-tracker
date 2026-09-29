import '../models/bus_live_location.dart';

enum TripProgressState {
  upcoming,
  active,
  staleActive,
  completed,
  trackingUnavailable,
}

class TripProgressInfo {
  final TripProgressState state;
  final String statusLabel;
  final int? currentSeqNo;
  final String? currentBoardingPoint;
  final bool isCompleted;

  const TripProgressInfo({
    required this.state,
    required this.statusLabel,
    this.currentSeqNo,
    this.currentBoardingPoint,
    required this.isCompleted,
  });

  bool get isStale => state == TripProgressState.staleActive;
  bool get isActive => state == TripProgressState.active;
  bool get isUpcoming => state == TripProgressState.upcoming;
  bool get isTrackingUnavailable =>
      state == TripProgressState.trackingUnavailable;
}

class TripProgressResolver {
  /// Resolves the overall trip state based on real backend fields and telemetry freshness.
  static TripProgressInfo resolve({
    required BusLiveLocation location,
    DateTime? currentTime,
  }) {
    final freshness = location.getFreshnessClassification(
      currentTime: currentTime,
    );

    // 1. Backend completed trip check
    final isCompletedBackend =
        location.tripStatus == '2' ||
        location.isAbnormalEndTrip ||
        (location.serviceEndedTimeStamp > 0);

    if (isCompletedBackend) {
      return TripProgressInfo(
        state: TripProgressState.completed,
        statusLabel: 'COMPLETED',
        currentSeqNo: location.currentSeqNo,
        currentBoardingPoint: location.currentBoardingPoint,
        isCompleted: true,
      );
    }

    // 2. Tracking unavailable check
    if (freshness.status == FreshnessStatus.trackingUnavailable) {
      return TripProgressInfo(
        state: TripProgressState.trackingUnavailable,
        statusLabel: 'TRACKING UNAVAILABLE',
        currentSeqNo: location.currentSeqNo,
        currentBoardingPoint: location.currentBoardingPoint,
        isCompleted: false,
      );
    }

    // 3. Upcoming trip check
    if (location.tripStatus == '0') {
      return TripProgressInfo(
        state: TripProgressState.upcoming,
        statusLabel: 'UPCOMING',
        currentSeqNo: location.currentSeqNo,
        currentBoardingPoint: location.currentBoardingPoint,
        isCompleted: false,
      );
    }

    // 4. Stale active vs Fresh active
    if (freshness.status == FreshnessStatus.stale) {
      return TripProgressInfo(
        state: TripProgressState.staleActive,
        statusLabel: 'LAST KNOWN LOCATION',
        currentSeqNo: location.currentSeqNo,
        currentBoardingPoint: location.currentBoardingPoint,
        isCompleted: false,
      );
    }

    // 5. Active (Live or Delayed)
    return TripProgressInfo(
      state: TripProgressState.active,
      statusLabel: freshness.status == FreshnessStatus.delayed
          ? 'GPS DELAYED'
          : 'LIVE',
      currentSeqNo: location.currentSeqNo,
      currentBoardingPoint: location.currentBoardingPoint,
      isCompleted: false,
    );
  }
}
