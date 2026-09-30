import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RecentTrackItem {
  final String vehicleNumber;
  final String serviceDocId;
  final String? oprsNo;
  final String? serviceType;
  final String? routeSummary;
  final DateTime lastTrackedAt;

  const RecentTrackItem({
    required this.vehicleNumber,
    required this.serviceDocId,
    this.oprsNo,
    this.serviceType,
    this.routeSummary,
    required this.lastTrackedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'vehicleNumber': vehicleNumber,
      'serviceDocId': serviceDocId,
      'oprsNo': oprsNo,
      'serviceType': serviceType,
      'routeSummary': routeSummary,
      'lastTrackedAt': lastTrackedAt.toIso8601String(),
    };
  }

  factory RecentTrackItem.fromJson(Map<String, dynamic> json) {
    return RecentTrackItem(
      vehicleNumber: json['vehicleNumber'] as String? ?? '',
      serviceDocId: json['serviceDocId'] as String? ?? '',
      oprsNo: json['oprsNo'] as String?,
      serviceType: json['serviceType'] as String?,
      routeSummary: json['routeSummary'] as String?,
      lastTrackedAt:
          DateTime.tryParse(json['lastTrackedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  String get displayService => oprsNo != null && oprsNo!.isNotEmpty
      ? 'Service #$oprsNo • ${serviceType ?? 'APSRTC'}'
      : (serviceType ?? 'APSRTC Bus');

  String get formattedTime {
    final diff = DateTime.now().difference(lastTrackedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class RecentTrackService {
  static const String _key = 'ap_recent_tracked_buses_v1';
  final SharedPreferences? prefs;

  RecentTrackService({this.prefs});

  Future<SharedPreferences> _getPrefs() async {
    return prefs ?? await SharedPreferences.getInstance();
  }

  Future<List<RecentTrackItem>> getRecentTracks() async {
    try {
      final prefs = await _getPrefs();
      final List<String>? rawList = prefs.getStringList(_key);
      if (rawList == null || rawList.isEmpty) {
        return [];
      }
      final items = <RecentTrackItem>[];
      for (final str in rawList) {
        try {
          final Map<String, dynamic> map = jsonDecode(str);
          final item = RecentTrackItem.fromJson(map);
          if (item.serviceDocId.isNotEmpty) {
            items.add(item);
          }
        } catch (_) {}
      }
      return items.take(5).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addRecentTrack(RecentTrackItem item) async {
    try {
      final current = await getRecentTracks();
      current.removeWhere(
        (existing) =>
            existing.vehicleNumber.replaceAll(' ', '').toUpperCase() ==
            item.vehicleNumber.replaceAll(' ', '').toUpperCase(),
      );
      current.insert(0, item);
      final limited = current.take(5).toList();

      final prefs = await _getPrefs();
      final encoded = limited.map((i) => jsonEncode(i.toJson())).toList();
      await prefs.setStringList(_key, encoded);
    } catch (_) {}
  }

  Future<void> clearRecentTracks() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
