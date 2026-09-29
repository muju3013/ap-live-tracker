class ApsrtcTrip {
  final String serviceDocId;
  final String oprsNo;
  final String journeyDate;
  final String depotName;
  final String serviceType;
  final bool isTrackingEnabled;

  const ApsrtcTrip({
    required this.serviceDocId,
    required this.oprsNo,
    required this.journeyDate,
    required this.depotName,
    required this.serviceType,
    required this.isTrackingEnabled,
  });

  factory ApsrtcTrip.fromFirestoreJson(Map<String, dynamic> json) {
    final fields = json['fields'] as Map<String, dynamic>? ?? {};
    return ApsrtcTrip(
      serviceDocId: fields['serviceDocId']?['stringValue'] ?? '',
      oprsNo: fields['oprsNo']?['stringValue'] ?? '',
      journeyDate: fields['journeyDate']?['stringValue'] ?? '',
      depotName: fields['depotName']?['stringValue'] ?? '',
      serviceType: fields['serviceType']?['stringValue'] ?? '',
      isTrackingEnabled: fields['enableTracking']?['stringValue'] == '1',
    );
  }
}
