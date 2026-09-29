import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/apsrtc_station.dart';

class ApsrtcPlaceRepository {
  List<ApsrtcStation>? _cachedPlaces;
  Map<String, ApsrtcStation>? _placeIdMap;
  Map<String, ApsrtcStation>? _linkPlaceIdMap;
  Map<String, ApsrtcStation>? _secondaryStopMap;

  int _firstLoadTimeMs = 0;
  int _lastSearchTimeMs = 0;

  int get firstLoadTimeMs => _firstLoadTimeMs;
  int get lastSearchTimeMs => _lastSearchTimeMs;
  int get totalPlacesLoaded => _cachedPlaces?.length ?? 0;
  int get uniquePlaceIdsCount => _placeIdMap?.length ?? 0;

  /// Loads places dataset from Flutter assets or provided JSON/encoded string.
  Future<List<ApsrtcStation>> loadPlaces({
    String assetPath = 'assets/data/apsrtc_places.json',
    String secondaryAssetPath = 'assets/data_files/bus_stops.json',
    String? rawDataOverride,
  }) async {
    if (_cachedPlaces != null) {
      return _cachedPlaces!;
    }

    final stopwatch = Stopwatch()..start();

    String content;
    if (rawDataOverride != null) {
      content = rawDataOverride;
    } else {
      content = await rootBundle.loadString(assetPath);
    }

    _processRawContent(content);

    try {
      final secondaryContent = await rootBundle.loadString(secondaryAssetPath);
      _processSecondaryStops(secondaryContent);
    } catch (_) {
      // Secondary asset optional for custom test data overrides
    }

    stopwatch.stop();
    _firstLoadTimeMs = stopwatch.elapsedMilliseconds;

    return _cachedPlaces!;
  }

  /// Synchronously load places from raw JSON or abhibus_enc_v1 string (for tests).
  List<ApsrtcStation> loadPlacesFromRaw(
    String rawContent, {
    String? secondaryRawContent,
  }) {
    final stopwatch = Stopwatch()..start();

    _processRawContent(rawContent);
    if (secondaryRawContent != null) {
      _processSecondaryStops(secondaryRawContent);
    }

    stopwatch.stop();
    _firstLoadTimeMs = stopwatch.elapsedMilliseconds;

    return _cachedPlaces!;
  }

  void _processRawContent(String rawContent) {
    String content = rawContent;
    // Isolate decoding logic for abhibus_enc_v1 prefix
    if (content.startsWith('abhibus_enc_v1:')) {
      final base64Part = content.substring('abhibus_enc_v1:'.length);
      content = utf8.decode(base64.decode(base64Part));
    }

    final Map<String, dynamic> decodedJson = jsonDecode(content);
    final List<dynamic> rawList =
        decodedJson['miniServicePlaces'] ?? decodedJson['placeInfos'] ?? [];

    final List<ApsrtcStation> stations = [];
    final Map<String, ApsrtcStation> idMap = {};
    final Map<String, ApsrtcStation> linkMap = {};

    for (final item in rawList) {
      if (item is Map<String, dynamic>) {
        final station = ApsrtcStation.fromJson(item);
        final cleanId = station.placeId.trim();
        final cleanLinkId = station.linkPlaceId.trim();

        if (cleanId.isNotEmpty && !idMap.containsKey(cleanId)) {
          stations.add(station);
          idMap[cleanId] = station;
        }
        if (cleanLinkId.isNotEmpty && !linkMap.containsKey(cleanLinkId)) {
          linkMap[cleanLinkId] = station;
        }
      }
    }

    _cachedPlaces = stations;
    _placeIdMap = idMap;
    _linkPlaceIdMap = linkMap;
  }

  void _processSecondaryStops(String rawContent) {
    final Map<String, dynamic> decodedJson = jsonDecode(rawContent);
    final List<dynamic> rawList =
        decodedJson['busStops'] ?? decodedJson['stops'] ?? [];

    final Map<String, ApsrtcStation> secMap = {};

    for (final item in rawList) {
      if (item is Map<String, dynamic>) {
        final stopId =
            (item['stopId'] ?? item['placeId'] ?? item['id'])
                ?.toString()
                .trim() ??
            '';
        final stopName =
            (item['stopName'] ?? item['placeName'] ?? item['name'])
                ?.toString()
                .trim() ??
            '';
        final mandalName = (item['mandalName'] ?? item['mandal'])
            ?.toString()
            .trim();
        final pinCode = (item['pinCode'] ?? item['pincode'])?.toString().trim();

        if (stopId.isNotEmpty && stopName.isNotEmpty) {
          // Never overwrite an existing primary placeId!
          if (!isMainPlace(stopId)) {
            secMap.putIfAbsent(
              stopId,
              () => ApsrtcStation(
                placeId: stopId,
                linkPlaceId: stopId,
                placeName: stopName,
                mandalName: mandalName,
                pinCode: pinCode,
                resolutionSource: 'secondaryStopDirectory',
              ),
            );
          }
        }
      }
    }

    _secondaryStopMap = secMap;
  }

  /// Check if placeId is present in canonical miniServicePlaces dataset.
  bool isMainPlace(String rawPlaceId) {
    final cleanId = rawPlaceId.trim();
    return (_placeIdMap?.containsKey(cleanId) ?? false) ||
        (_linkPlaceIdMap?.containsKey(cleanId) ?? false);
  }

  /// Get place by canonical placeId, linkPlaceId, or secondary stop directory ID.
  ApsrtcStation? getPlaceById(String rawPlaceId) {
    final cleanId = rawPlaceId.trim();
    if (cleanId.isEmpty) return null;
    return _placeIdMap?[cleanId] ??
        _linkPlaceIdMap?[cleanId] ??
        _secondaryStopMap?[cleanId];
  }

  /// Get stop by secondary stop directory ID.
  ApsrtcStation? getSecondaryStopById(String rawStopId) {
    final cleanId = rawStopId.trim();
    if (cleanId.isEmpty) return null;
    return _secondaryStopMap?[cleanId];
  }

  /// Normalized autocomplete search:
  /// - Case insensitive
  /// - Trim leading/trailing spaces
  /// - Collapse multiple spaces into single space
  /// - Ranking:
  ///   1. Exact placeName match
  ///   2. placeName starts with query
  ///   3. placeName contains query
  ///   Then stable alphabetical order.
  List<ApsrtcStation> searchPlaces(String rawQuery, {int limit = 30}) {
    final places = _cachedPlaces;
    if (places == null || places.isEmpty) {
      return [];
    }

    final cleanQuery = rawQuery.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    if (cleanQuery.isEmpty) {
      return places.take(limit).toList();
    }

    final stopwatch = Stopwatch()..start();

    final List<ApsrtcStation> exactMatches = [];
    final List<ApsrtcStation> startsWithMatches = [];
    final List<ApsrtcStation> containsMatches = [];

    for (final station in places) {
      final nameLower = station.placeName.toLowerCase();
      if (nameLower == cleanQuery) {
        exactMatches.add(station);
      } else if (nameLower.startsWith(cleanQuery)) {
        startsWithMatches.add(station);
      } else if (nameLower.contains(cleanQuery)) {
        containsMatches.add(station);
      }
    }

    // Sort each group alphabetically & by mandal/pincode for stability
    int compareStations(ApsrtcStation a, ApsrtcStation b) {
      final c1 = a.placeName.compareTo(b.placeName);
      if (c1 != 0) return c1;
      final c2 = (a.mandalName ?? '').compareTo(b.mandalName ?? '');
      if (c2 != 0) return c2;
      return a.placeId.compareTo(b.placeId);
    }

    exactMatches.sort(compareStations);
    startsWithMatches.sort(compareStations);
    containsMatches.sort(compareStations);

    final results = <ApsrtcStation>[
      ...exactMatches,
      ...startsWithMatches,
      ...containsMatches,
    ];

    stopwatch.stop();
    _lastSearchTimeMs = stopwatch.elapsedMilliseconds;

    return results.take(limit).toList();
  }
}
