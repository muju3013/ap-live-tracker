import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/apsrtc_station.dart';

class RecentSearchItem {
  final ApsrtcStation fromStation;
  final ApsrtcStation toStation;
  final String serviceType;
  final String distanceText;
  final DateTime timestamp;

  const RecentSearchItem({
    required this.fromStation,
    required this.toStation,
    this.serviceType = 'Express',
    this.distanceText = '142 km',
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'fromStation': fromStation.toJson(),
      'toStation': toStation.toJson(),
      'serviceType': serviceType,
      'distanceText': distanceText,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory RecentSearchItem.fromJson(Map<String, dynamic> json) {
    return RecentSearchItem(
      fromStation: ApsrtcStation.fromJson(
        json['fromStation'] as Map<String, dynamic>,
      ),
      toStation: ApsrtcStation.fromJson(
        json['toStation'] as Map<String, dynamic>,
      ),
      serviceType: json['serviceType'] as String? ?? 'Express',
      distanceText: json['distanceText'] as String? ?? '142 km',
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  String get routeTitle => '${fromStation.placeName} → ${toStation.placeName}';
  String get subtitle => '$serviceType • $distanceText';
}

class RecentSearchService {
  static const String _key = 'ap_recent_searches_v1';
  final SharedPreferences? prefs;

  RecentSearchService({this.prefs});

  Future<SharedPreferences> _getPrefs() async {
    return prefs ?? await SharedPreferences.getInstance();
  }

  Future<List<RecentSearchItem>> getRecentSearches() async {
    try {
      final prefs = await _getPrefs();
      final List<String>? rawList = prefs.getStringList(_key);
      if (rawList == null || rawList.isEmpty) {
        return _getDefaultRecentSearches();
      }
      final items = <RecentSearchItem>[];
      for (final str in rawList) {
        try {
          final Map<String, dynamic> map = jsonDecode(str);
          items.add(RecentSearchItem.fromJson(map));
        } catch (_) {}
      }
      return items.take(5).toList();
    } catch (_) {
      return _getDefaultRecentSearches();
    }
  }

  Future<void> addRecentSearch(
    ApsrtcStation from,
    ApsrtcStation to, {
    String serviceType = 'Express',
    String distanceText = '142 km',
  }) async {
    try {
      final current = await getRecentSearches();
      // Remove any existing duplicate route
      current.removeWhere(
        (item) =>
            item.fromStation.placeId == from.placeId &&
            item.toStation.placeId == to.placeId,
      );

      final newItem = RecentSearchItem(
        fromStation: from,
        toStation: to,
        serviceType: serviceType,
        distanceText: distanceText,
        timestamp: DateTime.now(),
      );

      current.insert(0, newItem);
      final limited = current.take(5).toList();

      final prefs = await _getPrefs();
      final encoded = limited.map((item) => jsonEncode(item.toJson())).toList();
      await prefs.setStringList(_key, encoded);
    } catch (_) {}
  }

  Future<void> clearRecentSearches() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_key);
    } catch (_) {}
  }

  List<RecentSearchItem> _getDefaultRecentSearches() {
    return [
      RecentSearchItem(
        fromStation: const ApsrtcStation(
          placeId: '14911',
          linkPlaceId: '14911',
          placeName: 'TIRUPATHI',
          mandalName: 'TIRUPATI URBAN',
          pinCode: '517501',
        ),
        toStation: const ApsrtcStation(
          placeId: '6021',
          linkPlaceId: '6021',
          placeName: 'KADAPA',
          mandalName: 'KADAPA',
          pinCode: '516001',
        ),
        serviceType: 'Express',
        distanceText: '142 km',
        timestamp: DateTime.now(),
      ),
    ];
  }
}
