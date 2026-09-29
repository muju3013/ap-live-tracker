import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/apsrtc_service_search_result.dart';
import '../models/apsrtc_station.dart';
import 'apsrtc_place_repository.dart';

/// Service for handling APSRTC service searches against upstream API.
class ApsrtcSearchService {
  static const String servicesAllEndpoint =
      'https://utsappapicached01.apsrtconline.in/uts-vts-api/services/all';

  final http.Client _client;
  final Map<String, String>? _extraHeaders;
  final ApsrtcPlaceRepository _placeRepository;

  int _lastSearchApiCallCount = 0;
  int _rawServiceCount = 0;
  int _passengerVisibleCount = 0;
  int _upcomingCount = 0;
  int _cancelledCount = 0;

  int get lastSearchApiCallCount => _lastSearchApiCallCount;
  int get rawServiceCount => _rawServiceCount;
  int get passengerVisibleCount => _passengerVisibleCount;
  int get upcomingCount => _upcomingCount;
  int get cancelledCount => _cancelledCount;

  ApsrtcSearchService({
    http.Client? client,
    this._extraHeaders,
    ApsrtcPlaceRepository? placeRepository,
  }) : _client = client ?? http.Client(),
       _placeRepository = placeRepository ?? ApsrtcPlaceRepository();

  ApsrtcPlaceRepository get placeRepository => _placeRepository;

  /// Generates today's date dynamically in India Standard Time (IST, UTC+5:30).
  /// Format: 'DD-MMM-YYYY' (e.g. '27-Sep-2026').
  static String getTodayApsrtcDate([DateTime? overrideNow]) {
    final nowIst = (overrideNow ?? DateTime.now()).toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    final day = nowIst.day.toString().padLeft(2, '0');
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[nowIst.month - 1];
    final year = nowIst.year;
    return '$day-$month-$year';
  }

  /// Resolves an ApsrtcStation by placeId, placeName, or search query.
  ApsrtcStation resolveStation(String query) {
    final clean = query.trim();
    if (clean.isEmpty) {
      return const ApsrtcStation(
        placeId: '14911',
        linkPlaceId: '14911',
        placeName: 'TIRUPATHI',
      );
    }

    // Direct placeId lookup
    final byId = _placeRepository.getPlaceById(clean);
    if (byId != null) return byId;

    // Search lookup
    final results = _placeRepository.searchPlaces(clean, limit: 1);
    if (results.isNotEmpty) return results.first;

    // Fallback station mapping for legacy IDs/names if repository not loaded yet
    final upper = clean.toUpperCase();
    if (upper == 'CHITTOOR' || clean == '2821') {
      return const ApsrtcStation(
        placeId: '2821',
        linkPlaceId: '2821',
        placeName: 'CHITTOOR',
      );
    }
    if (upper == 'PILER' || clean == '11821') {
      return const ApsrtcStation(
        placeId: '11821',
        linkPlaceId: '11821',
        placeName: 'PILER',
      );
    }
    if (upper == 'TIRUPATHI' || clean == '14911') {
      return const ApsrtcStation(
        placeId: '14911',
        linkPlaceId: '14911',
        placeName: 'TIRUPATHI',
      );
    }
    if (upper == 'KADAPA' || clean == '6021') {
      return const ApsrtcStation(
        placeId: '6021',
        linkPlaceId: '6021',
        placeName: 'KADAPA',
      );
    }
    if (upper == 'DAMALCHERVU' || clean == '3081') {
      return const ApsrtcStation(
        placeId: '3081',
        linkPlaceId: '3081',
        placeName: 'DAMALCHERVU',
      );
    }
    if (upper == 'KALLURU' || clean == '224342') {
      return const ApsrtcStation(
        placeId: '224342',
        linkPlaceId: '224342',
        placeName: 'KALLURU',
        mandalName: 'PULICHERLA',
        pinCode: '517113',
      );
    }

    return ApsrtcStation(placeId: clean, linkPlaceId: clean, placeName: upper);
  }

  /// Alias for resolveStation for backward compatibility.
  ApsrtcStation? findStation(String query) => resolveStation(query);

  /// Primary search mechanism using real APSRTC REST API `/services/all`.
  /// Performs single POST request (no N+1 GPS GETs during initial search).
  Future<List<ApsrtcServiceSearchResult>> searchServices({
    ApsrtcStation? fromStation,
    ApsrtcStation? toStation,
    String? from,
    String? to,
    DateTime? overrideDate,
  }) async {
    _lastSearchApiCallCount = 0;
    _rawServiceCount = 0;
    _passengerVisibleCount = 0;
    _upcomingCount = 0;
    _cancelledCount = 0;

    final ApsrtcStation resolvedFrom =
        fromStation ?? resolveStation(from ?? 'TIRUPATHI');
    final ApsrtcStation resolvedTo =
        toStation ?? resolveStation(to ?? 'KADAPA');

    final sourcePlaceId =
        int.tryParse(resolvedFrom.placeId) ?? int.parse(resolvedFrom.placeId);
    final sourceLinkId =
        int.tryParse(resolvedFrom.linkPlaceId) ??
        int.tryParse(resolvedFrom.placeId) ??
        sourcePlaceId;

    final destPlaceId =
        int.tryParse(resolvedTo.placeId) ?? int.parse(resolvedTo.placeId);
    final destLinkId =
        int.tryParse(resolvedTo.linkPlaceId) ??
        int.tryParse(resolvedTo.placeId) ??
        destPlaceId;

    final payload = {
      "sourceLinkId": sourceLinkId,
      "destinationLinkId": destLinkId,
      "sourcePlaceId": sourcePlaceId,
      "destinationPlaceId": destPlaceId,
      "userId": "1",
      "versionCode": 322,
      "apiVersion": 1,
    };

    final headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      ...?_extraHeaders,
    };

    _lastSearchApiCallCount++;

    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final response = await _client
            .post(
              Uri.parse(servicesAllEndpoint),
              headers: headers,
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final data = decoded['data'];

          if (data is List) {
            _rawServiceCount = data.length;
            final List<ApsrtcServiceSearchResult> visibleList = [];

            for (final item in data) {
              if (item is Map<String, dynamic>) {
                final result = ApsrtcServiceSearchResult.fromUtsApiJson(
                  item,
                  userFromStop: resolvedFrom.placeName,
                  userToStop: resolvedTo.placeName,
                );

                if (result.isCancel) {
                  _cancelledCount++;
                } else {
                  _passengerVisibleCount++;
                  visibleList.add(result);
                }
              }
            }

            _upcomingCount = visibleList
                .where((s) => s.status == BusServiceStatus.upcoming)
                .length;

            visibleList.sort((a, b) {
              if (a.status == BusServiceStatus.upcoming &&
                  b.status == BusServiceStatus.upcoming) {
                return a.departureTimeNum.compareTo(b.departureTimeNum);
              }
              if (a.status == BusServiceStatus.upcoming) return -1;
              if (b.status == BusServiceStatus.upcoming) return 1;
              return a.departureTimeNum.compareTo(b.departureTimeNum);
            });

            return visibleList;
          }
        }
      } catch (_) {
        if (attempt == 2) rethrow;
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    throw Exception(
      'APSRTC /services/all API request failed for route ${resolvedFrom.placeName} -> ${resolvedTo.placeName}',
    );
  }
}
