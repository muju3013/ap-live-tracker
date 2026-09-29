enum BusServiceStatus { running, upcoming, completed, trackingUnavailable }

class ApsrtcServiceSearchResult {
  final String serviceDocId;
  final String serviceNumber;
  final String source;
  final String destination;
  final String fromStop;
  final String toStop;
  final String serviceType;
  final String scheduledDeparture;
  final String scheduledArrival;
  final String depot;
  final String journeyDate;
  final BusServiceStatus status;
  final String statusText;
  final String? vehicleNumber;
  final bool isTrackingAvailable;
  final String? currentStop;
  final String? nextStop;
  final String? lastGpsUpdate;
  final String? wayPointString;
  final String? viaSummary;
  final int departureTimeNum;
  final int arrivalTimeNum;
  final int departureDay;
  final int arrivalDay;
  final bool isCancel;
  final bool isClose;
  final bool isDirect;
  final bool exactMatch;

  const ApsrtcServiceSearchResult({
    required this.serviceDocId,
    required this.serviceNumber,
    required this.source,
    required this.destination,
    required this.fromStop,
    required this.toStop,
    required this.serviceType,
    required this.scheduledDeparture,
    required this.scheduledArrival,
    required this.depot,
    required this.journeyDate,
    required this.status,
    required this.statusText,
    this.vehicleNumber,
    required this.isTrackingAvailable,
    this.currentStop,
    this.nextStop,
    this.lastGpsUpdate,
    this.wayPointString,
    this.viaSummary,
    this.departureTimeNum = 0,
    this.arrivalTimeNum = 0,
    this.departureDay = 0,
    this.arrivalDay = 0,
    this.isCancel = false,
    this.isClose = false,
    this.isDirect = false,
    this.exactMatch = true,
  });

  factory ApsrtcServiceSearchResult.fromUtsApiJson(
    Map<String, dynamic> json, {
    required String userFromStop,
    required String userToStop,
    DateTime? currentTime,
  }) {
    final oprsNo = json['oprsNo']?.toString() ?? '';
    final serviceId = json['serviceId']?.toString() ?? oprsNo;
    final docId = json['serviceDocId']?.toString() ?? '';
    final srcName = json['sourceName']?.toString() ?? userFromStop;
    final dstName = json['destinationName']?.toString() ?? userToStop;
    final sType = json['serviceType']?.toString() ?? '';
    final sStart = json['serviceStartTime']?.toString() ?? 'N/A';
    final sEnd = json['serviceEndTime']?.toString() ?? 'N/A';
    final depotName = json['depotName']?.toString() ?? '';
    final dateStr = json['journeyDate']?.toString() ?? '';

    final depTimeNum = json['departureTimeNum'] is num
        ? (json['departureTimeNum'] as num).toInt()
        : int.tryParse(json['departureTimeNum']?.toString() ?? '') ?? 0;

    final arrTimeStr = json['arrivalTime']?.toString() ?? '';
    final arrTimeNum = int.tryParse(arrTimeStr) ?? 0;

    final depDay = json['departureDay'] is num
        ? (json['departureDay'] as num).toInt()
        : int.tryParse(json['departureDay']?.toString() ?? '') ?? 0;

    final arrDay = json['arrivalDay'] is num
        ? (json['arrivalDay'] as num).toInt()
        : int.tryParse(json['arrivalDay']?.toString() ?? '') ?? 0;

    final cancelled =
        json['isCancel'] == true ||
        json['isCancel'] == 'true' ||
        json['isCancel'] == 1;

    final closed =
        json['isClose'] == true ||
        json['isClose'] == 'true' ||
        json['isClose'] == 1;

    final direct =
        json['isDirect'] == true ||
        json['isDirect'] == 'true' ||
        json['isDirect'] == 1;

    final exact =
        json['exactMatch'] == true ||
        json['exactMatch'] == 'true' ||
        json['exactMatch'] == 1;

    // Calculate current time in IST (HHmm format e.g. 15:30 -> 1530)
    final nowIst = (currentTime ?? DateTime.now()).toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    final currentMinutes = nowIst.hour * 100 + nowIst.minute;

    BusServiceStatus computedStatus;
    String label;

    if (cancelled) {
      computedStatus = BusServiceStatus.completed;
      label = 'CANCELLED';
    } else if (closed) {
      computedStatus = BusServiceStatus.completed;
      label = 'COMPLETED';
    } else if (depTimeNum > currentMinutes) {
      computedStatus = BusServiceStatus.upcoming;
      label = 'UPCOMING';
    } else if (arrTimeNum > 0 && arrTimeNum > currentMinutes) {
      computedStatus = BusServiceStatus.running;
      label = 'DEPARTED';
    } else {
      computedStatus = BusServiceStatus.completed;
      label = 'COMPLETED';
    }

    return ApsrtcServiceSearchResult(
      serviceDocId: docId,
      serviceNumber: oprsNo.isNotEmpty ? oprsNo : serviceId,
      source: srcName,
      destination: dstName,
      fromStop: userFromStop,
      toStop: userToStop,
      serviceType: sType,
      scheduledDeparture: sStart,
      scheduledArrival: sEnd,
      depot: depotName,
      journeyDate: dateStr,
      status: computedStatus,
      statusText: label,
      isTrackingAvailable:
          docId.isNotEmpty && computedStatus != BusServiceStatus.completed,
      departureTimeNum: depTimeNum,
      arrivalTimeNum: arrTimeNum,
      departureDay: depDay,
      arrivalDay: arrDay,
      isCancel: cancelled,
      isClose: closed,
      isDirect: direct,
      exactMatch: exact,
    );
  }

  factory ApsrtcServiceSearchResult.fromFirestoreJson(
    Map<String, dynamic> json, {
    required String userFromStop,
    required String userToStop,
    bool hasLiveTelemetry = false,
    String? liveVehicleNumber,
    String? liveRefreshedTime,
  }) {
    final fields = json['fields'] as Map<String, dynamic>? ?? {};

    final docId = _parseString(fields['serviceDocId']) ?? '';
    final oprsNo = _parseString(fields['oprsNo']) ?? '';
    final serviceNum = _parseString(fields['serviceNumber']) ?? oprsNo;
    final sourceName = _parseString(fields['sourceName']) ?? '';
    final destName = _parseString(fields['destinationName']) ?? '';
    final sType = _parseString(fields['serviceType']) ?? '';
    final sStart = _parseString(fields['serviceStartTime']) ?? 'N/A';
    final sEnd = _parseString(fields['serviceEndTime']) ?? 'N/A';
    final depotName = _parseString(fields['depotName']) ?? '';
    final dateStr = _parseString(fields['journeyDate']) ?? '';
    final rawTripStatus = _parseString(fields['tripStatus']) ?? '';
    final enableTrackingStr = _parseString(fields['enableTracking']) ?? '0';
    final isTrackingEnabled = enableTrackingStr == '1';
    final isAbnormalEnd = fields['isAbnormalEndTrip']?['booleanValue'] == true;
    final wayPointsStr = _parseString(fields['wayPointString']);

    final vehicle =
        liveVehicleNumber ??
        _parseString(fields['vehicleNumber']) ??
        _parseString(fields['busNumber']);

    final currBoarding = _parseString(fields['currentBoardingPoint']);
    final prevBoarding = _parseString(fields['prevBoardingPoint']);

    BusServiceStatus computedStatus;
    String label;

    if (rawTripStatus == '2' || isAbnormalEnd) {
      computedStatus = BusServiceStatus.completed;
      label = 'COMPLETED';
    } else if (rawTripStatus == '1' ||
        (isTrackingEnabled && hasLiveTelemetry)) {
      if (hasLiveTelemetry) {
        computedStatus = BusServiceStatus.running;
        label = 'RUNNING';
      } else {
        computedStatus = BusServiceStatus.trackingUnavailable;
        label = 'TRACKING UNAVAILABLE';
      }
    } else if (rawTripStatus == '0') {
      computedStatus = BusServiceStatus.upcoming;
      label = 'UPCOMING';
    } else {
      if (hasLiveTelemetry) {
        computedStatus = BusServiceStatus.running;
        label = 'RUNNING';
      } else {
        computedStatus = BusServiceStatus.trackingUnavailable;
        label = 'TRACKING UNAVAILABLE';
      }
    }

    return ApsrtcServiceSearchResult(
      serviceDocId: docId,
      serviceNumber: serviceNum.isNotEmpty ? serviceNum : oprsNo,
      source: sourceName,
      destination: destName,
      fromStop: userFromStop,
      toStop: userToStop,
      serviceType: sType,
      scheduledDeparture: sStart,
      scheduledArrival: sEnd,
      depot: depotName,
      journeyDate: dateStr,
      status: computedStatus,
      statusText: label,
      vehicleNumber: vehicle,
      isTrackingAvailable:
          hasLiveTelemetry && computedStatus != BusServiceStatus.completed,
      currentStop: currBoarding,
      nextStop: prevBoarding,
      lastGpsUpdate: liveRefreshedTime ?? _parseString(fields['refreshedAt']),
      wayPointString: wayPointsStr,
    );
  }

  ApsrtcServiceSearchResult copyWith({
    BusServiceStatus? status,
    String? statusText,
    bool? isTrackingAvailable,
    String? vehicleNumber,
    String? lastGpsUpdate,
    String? viaSummary,
  }) {
    return ApsrtcServiceSearchResult(
      serviceDocId: serviceDocId,
      serviceNumber: serviceNumber,
      source: source,
      destination: destination,
      fromStop: fromStop,
      toStop: toStop,
      serviceType: serviceType,
      scheduledDeparture: scheduledDeparture,
      scheduledArrival: scheduledArrival,
      depot: depot,
      journeyDate: journeyDate,
      status: status ?? this.status,
      statusText: statusText ?? this.statusText,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      isTrackingAvailable: isTrackingAvailable ?? this.isTrackingAvailable,
      currentStop: currentStop,
      nextStop: nextStop,
      lastGpsUpdate: lastGpsUpdate ?? this.lastGpsUpdate,
      wayPointString: wayPointString,
      viaSummary: viaSummary ?? this.viaSummary,
      departureTimeNum: departureTimeNum,
      arrivalTimeNum: arrivalTimeNum,
      departureDay: departureDay,
      arrivalDay: arrivalDay,
      isCancel: isCancel,
      isClose: isClose,
      isDirect: isDirect,
      exactMatch: exactMatch,
    );
  }

  static String? _parseString(dynamic map) {
    if (map == null || map is! Map) return null;
    if (map.containsKey('stringValue')) return map['stringValue']?.toString();
    if (map.containsKey('integerValue')) return map['integerValue']?.toString();
    if (map.containsKey('doubleValue')) return map['doubleValue']?.toString();
    return null;
  }
}
