class ApsrtcRouteStop {
  final String stationId;
  final String placeName;
  final String? mandalName;
  final String? pinCode;
  final int sequenceNo;
  final String? scheduledArrival;
  final String? scheduledDeparture;
  final String? actualArrival;
  final String? actualDeparture;
  final String? eta;
  final bool isSkipped;
  final bool isBoardingStop;
  final bool isDropStop;
  final bool isIntermediate;
  final String resolvedSource;

  const ApsrtcRouteStop({
    required this.stationId,
    required this.placeName,
    this.mandalName,
    this.pinCode,
    required this.sequenceNo,
    this.scheduledArrival,
    this.scheduledDeparture,
    this.actualArrival,
    this.actualDeparture,
    this.eta,
    this.isSkipped = false,
    this.isBoardingStop = false,
    this.isDropStop = false,
    this.isIntermediate = false,
    this.resolvedSource = 'unresolved',
  });

  ApsrtcRouteStop copyWith({
    bool? isBoardingStop,
    bool? isDropStop,
    bool? isIntermediate,
    bool? isSkipped,
    String? scheduledArrival,
    String? scheduledDeparture,
    String? actualArrival,
    String? actualDeparture,
    String? eta,
    String? resolvedSource,
  }) {
    return ApsrtcRouteStop(
      stationId: stationId,
      placeName: placeName,
      mandalName: mandalName,
      pinCode: pinCode,
      sequenceNo: sequenceNo,
      scheduledArrival: scheduledArrival ?? this.scheduledArrival,
      scheduledDeparture: scheduledDeparture ?? this.scheduledDeparture,
      actualArrival: actualArrival ?? this.actualArrival,
      actualDeparture: actualDeparture ?? this.actualDeparture,
      eta: eta ?? this.eta,
      isSkipped: isSkipped ?? this.isSkipped,
      isBoardingStop: isBoardingStop ?? this.isBoardingStop,
      isDropStop: isDropStop ?? this.isDropStop,
      isIntermediate: isIntermediate ?? this.isIntermediate,
      resolvedSource: resolvedSource ?? this.resolvedSource,
    );
  }
}

class ApsrtcRouteSegmentResult {
  final String serviceDocId;
  final List<ApsrtcRouteStop> fullRouteStops;
  final List<ApsrtcRouteStop> visibleSegmentStops;
  final List<ApsrtcRouteStop> intermediateStops;
  final String viaSummary;
  final int fromIndex;
  final int toIndex;
  final bool isValidSegment;
  final bool isDirectService;

  const ApsrtcRouteSegmentResult({
    required this.serviceDocId,
    required this.fullRouteStops,
    required this.visibleSegmentStops,
    required this.intermediateStops,
    required this.viaSummary,
    required this.fromIndex,
    required this.toIndex,
    required this.isValidSegment,
    required this.isDirectService,
  });

  factory ApsrtcRouteSegmentResult.direct({
    required String serviceDocId,
    required List<ApsrtcRouteStop> stops,
    String? fromStop,
    String? toStop,
  }) {
    return ApsrtcRouteSegmentResult(
      serviceDocId: serviceDocId,
      fullRouteStops: stops,
      visibleSegmentStops: stops,
      intermediateStops: const [],
      viaSummary: 'Direct service',
      fromIndex: 0,
      toIndex: stops.length > 1 ? stops.length - 1 : 0,
      isValidSegment: true,
      isDirectService: true,
    );
  }
}
