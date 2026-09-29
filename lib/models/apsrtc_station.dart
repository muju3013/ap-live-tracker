class ApsrtcStation {
  final String placeId;
  final String linkPlaceId;
  final String placeName;
  final String? pinCode;
  final String? mandalName;
  final double? latitude;
  final double? longitude;
  final String resolutionSource;

  const ApsrtcStation({
    required this.placeId,
    required this.linkPlaceId,
    required this.placeName,
    this.pinCode,
    this.mandalName,
    this.latitude,
    this.longitude,
    this.resolutionSource = 'miniServicePlaces',
  });

  ApsrtcStation copyWith({
    String? placeId,
    String? linkPlaceId,
    String? placeName,
    String? pinCode,
    String? mandalName,
    double? latitude,
    double? longitude,
    String? resolutionSource,
  }) {
    return ApsrtcStation(
      placeId: placeId ?? this.placeId,
      linkPlaceId: linkPlaceId ?? this.linkPlaceId,
      placeName: placeName ?? this.placeName,
      pinCode: pinCode ?? this.pinCode,
      mandalName: mandalName ?? this.mandalName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      resolutionSource: resolutionSource ?? this.resolutionSource,
    );
  }

  /// Backward-compatibility alias for stationId (alias for placeId)
  String get stationId => placeId;

  /// Backward-compatibility alias for placeCode
  String get placeCode => placeId;

  /// Returns station name for convenience.
  String get name => placeName;

  /// Display subtitle formatted with mandalName and pinCode.
  /// Never returns "null" or displays null strings.
  String get displaySubtitle {
    final parts = <String>[];
    if (mandalName != null &&
        mandalName!.trim().isNotEmpty &&
        mandalName != 'null') {
      parts.add(mandalName!.trim());
    }
    if (pinCode != null && pinCode!.trim().isNotEmpty && pinCode != 'null') {
      parts.add(pinCode!.trim());
    }
    return parts.join(' • ');
  }

  factory ApsrtcStation.fromJson(Map<String, dynamic> json) {
    return ApsrtcStation(
      placeId: (json['placeId'] ?? json['id'])?.toString() ?? '',
      linkPlaceId:
          (json['linkPlaceId'] ?? json['placeId'] ?? json['id'])?.toString() ??
          '',
      placeName: (json['placeName'] ?? '').toString().trim(),
      pinCode: (json['pinCode'] ?? json['pincode'])?.toString().trim(),
      mandalName: (json['mandalName'] ?? json['mandal'])?.toString().trim(),
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'placeId': placeId,
    'linkPlaceId': linkPlaceId,
    'placeName': placeName,
    if (pinCode != null) 'pinCode': pinCode,
    if (mandalName != null) 'mandalName': mandalName,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApsrtcStation &&
          runtimeType == other.runtimeType &&
          placeId == other.placeId;

  @override
  int get hashCode => placeId.hashCode;

  @override
  String toString() => '$placeName ($placeId)';
}
