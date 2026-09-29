import '../utils/tracking_freshness.dart';

export '../utils/tracking_freshness.dart'
    show FreshnessStatus, FreshnessClassification, TrackingFreshnessClassifier;

class BusLiveLocation {
  final String vehicleNumber;
  final String oprsNo;
  final String serviceType;
  final double latitude;
  final double longitude;
  final double speed;
  final double locationBearing;
  final double locationAltitude;
  final String locationTime;
  final int refreshedAt;
  final bool isOnline;
  final String serviceDocId;
  final String tripStatus;
  final bool isAbnormalEndTrip;
  final int serviceEndedTimeStamp;
  final int? currentSeqNo;
  final int? prevSeqNo;
  final String? currentBoardingPoint;
  final String? prevBoardingPoint;
  final String? stageCloseId;
  final String? stageLeftId;

  const BusLiveLocation({
    required this.vehicleNumber,
    required this.oprsNo,
    required this.serviceType,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.locationBearing,
    required this.locationAltitude,
    required this.locationTime,
    required this.refreshedAt,
    required this.isOnline,
    required this.serviceDocId,
    this.tripStatus = '1',
    this.isAbnormalEndTrip = false,
    this.serviceEndedTimeStamp = 0,
    this.currentSeqNo,
    this.prevSeqNo,
    this.currentBoardingPoint,
    this.prevBoardingPoint,
    this.stageCloseId,
    this.stageLeftId,
  });

  factory BusLiveLocation.fromFirestoreJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? serviceDetailsJson,
  }) {
    final fields = json['fields'] as Map<String, dynamic>? ?? {};
    final detailFields =
        serviceDetailsJson?['fields'] as Map<String, dynamic>? ?? {};

    final combinedFields = Map<String, dynamic>.from(fields)
      ..addAll(detailFields);

    return BusLiveLocation(
      vehicleNumber: _parseString(combinedFields['vehicleNumber']) ?? '',
      oprsNo: _parseString(combinedFields['oprsNo']) ?? '',
      serviceType: _parseString(combinedFields['serviceType']) ?? '',
      latitude: _parseDouble(combinedFields['latitude']) ?? 0.0,
      longitude: _parseDouble(combinedFields['longitude']) ?? 0.0,
      speed: _parseDouble(combinedFields['speed']) ?? 0.0,
      locationBearing: _parseDouble(combinedFields['locationBearing']) ?? 0.0,
      locationAltitude: _parseDouble(combinedFields['locationAltitude']) ?? 0.0,
      locationTime: _parseString(combinedFields['locationTime']) ?? '',
      refreshedAt: _parseInt(combinedFields['refreshedAt']) ?? 0,
      isOnline: _parseBool(combinedFields['isOnline']),
      serviceDocId: _parseString(combinedFields['serviceDocId']) ?? '',
      tripStatus: _parseString(combinedFields['tripStatus']) ?? '1',
      isAbnormalEndTrip: _parseBool(combinedFields['isAbnormalEndTrip']),
      serviceEndedTimeStamp:
          _parseInt(combinedFields['serviceEndedTimeStamp']) ?? 0,
      currentSeqNo: _parseInt(combinedFields['currentSeqNo']),
      prevSeqNo: _parseInt(combinedFields['prevSeqNo']),
      currentBoardingPoint: _parseString(
        combinedFields['currentBoardingPoint'],
      ),
      prevBoardingPoint: _parseString(combinedFields['prevBoardingPoint']),
      stageCloseId: _parseString(combinedFields['stageCloseId']),
      stageLeftId: _parseString(combinedFields['stageLeftId']),
    );
  }

  /// Calculates complete freshness classification using shared TrackingFreshnessClassifier
  FreshnessClassification getFreshnessClassification({DateTime? currentTime}) {
    return TrackingFreshnessClassifier.classify(
      isOnline: isOnline,
      refreshedAt: refreshedAt,
      locationTime: locationTime,
      currentTime: currentTime,
    );
  }

  /// Calculates freshness status based on refreshedAt or locationTime timestamp.
  FreshnessStatus getFreshnessStatus({DateTime? currentTime}) {
    return getFreshnessClassification(currentTime: currentTime).status;
  }

  /// Returns calculated age in seconds.
  int getAgeInSeconds({DateTime? currentTime}) {
    return getFreshnessClassification(currentTime: currentTime).ageInSeconds;
  }

  static double? _parseDouble(dynamic fieldMap) {
    if (fieldMap == null || fieldMap is! Map) return null;
    if (fieldMap.containsKey('doubleValue')) {
      final val = fieldMap['doubleValue'];
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
    }
    if (fieldMap.containsKey('integerValue')) {
      final val = fieldMap['integerValue'];
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
    }
    if (fieldMap.containsKey('stringValue')) {
      final val = fieldMap['stringValue'];
      if (val is String) return double.tryParse(val);
      if (val is num) return val.toDouble();
    }
    return null;
  }

  static int? _parseInt(dynamic fieldMap) {
    if (fieldMap == null || fieldMap is! Map) return null;
    if (fieldMap.containsKey('integerValue')) {
      final val = fieldMap['integerValue'];
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val);
    }
    if (fieldMap.containsKey('stringValue')) {
      final val = fieldMap['stringValue'];
      if (val is String) return int.tryParse(val);
      if (val is num) return val.toInt();
    }
    if (fieldMap.containsKey('doubleValue')) {
      final val = fieldMap['doubleValue'];
      if (val is num) return val.toInt();
      if (val is String) return double.tryParse(val)?.toInt();
    }
    return null;
  }

  static String? _parseString(dynamic fieldMap) {
    if (fieldMap == null || fieldMap is! Map) return null;
    if (fieldMap.containsKey('stringValue')) {
      return fieldMap['stringValue']?.toString();
    }
    if (fieldMap.containsKey('integerValue')) {
      return fieldMap['integerValue']?.toString();
    }
    if (fieldMap.containsKey('doubleValue')) {
      return fieldMap['doubleValue']?.toString();
    }
    return null;
  }

  static bool _parseBool(dynamic fieldMap) {
    if (fieldMap == null || fieldMap is! Map) return false;
    final val =
        fieldMap['stringValue'] ??
        fieldMap['integerValue'] ??
        fieldMap['booleanValue'];
    if (val == null) return false;
    if (val is bool) return val;
    final str = val.toString().trim().toLowerCase();
    return str == '1' || str == 'true';
  }
}
