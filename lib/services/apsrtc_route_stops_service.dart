import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/apsrtc_route_stop.dart';
import '../models/apsrtc_station.dart';
import 'apsrtc_place_repository.dart';

/// Reusable service for resolving real APSRTC route stops and segment summaries.
class ApsrtcRouteStopsService {
  static const String firestoreBaseUrl =
      'https://firestore.googleapis.com/v1/projects/apsrtc-uts-prod/databases/(default)/documents/serviceDetails';

  final http.Client _client;
  final ApsrtcPlaceRepository _placeRepository;
  final Map<String, ApsrtcRouteSegmentResult> _cache = {};

  ApsrtcRouteStopsService({
    http.Client? client,
    ApsrtcPlaceRepository? placeRepository,
  }) : _client = client ?? http.Client(),
       _placeRepository = placeRepository ?? ApsrtcPlaceRepository();

  /// Returns cached route result by serviceDocId if already resolved.
  ApsrtcRouteSegmentResult? getCachedRoute(String serviceDocId) {
    if (serviceDocId.isEmpty) return null;
    for (final entry in _cache.entries) {
      if (entry.key.startsWith(serviceDocId)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Resolves the route stops and segment summary for a given service and FROM/TO pair.
  Future<ApsrtcRouteSegmentResult> resolveRouteStops({
    required String serviceDocId,
    String? wayPointString,
    ApsrtcStation? fromStation,
    ApsrtcStation? toStation,
    String? fromName,
    String? toName,
    Map<String, String>? enrichedStopNames,
    Map<String, ApsrtcRouteStop>? enrichedStopMetadata,
  }) async {
    final cacheKey =
        '${serviceDocId}_${fromStation?.placeId ?? fromName}_${toStation?.placeId ?? toName}';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final cached = getCachedRoute(serviceDocId);
    if (cached != null) {
      // Re-slice segment if cached for different FROM/TO pair
      final reSliced = _sliceSegment(
        serviceDocId: serviceDocId,
        fullStops: cached.fullRouteStops,
        fromStation: fromStation,
        toStation: toStation,
        fromName: fromName,
        toName: toName,
      );
      _cache[cacheKey] = reSliced;
      return reSliced;
    }

    await _placeRepository.loadPlaces();

    String? activeWaypoints = wayPointString;

    // Fetch from serviceDetails REST API if not provided
    if ((activeWaypoints == null || activeWaypoints.isEmpty) &&
        serviceDocId.isNotEmpty) {
      activeWaypoints = await _fetchWayPointStringFromFirestore(serviceDocId);
    }

    if (activeWaypoints == null || activeWaypoints.trim().isEmpty) {
      final fallbackStops = _createFallbackStops(
        fromStation: fromStation,
        toStation: toStation,
        fromName: fromName,
        toName: toName,
      );
      final result = ApsrtcRouteSegmentResult.direct(
        serviceDocId: serviceDocId,
        stops: fallbackStops,
      );
      _cache[cacheKey] = result;
      return result;
    }

    // 1. Resolve raw waypoint string into ApsrtcRouteStop objects (DO NOT filter out 13-digit IDs)
    final rawIds = activeWaypoints.split(',');
    final List<ApsrtcRouteStop> fullStops = [];
    int seq = 1;

    for (final rawId in rawIds) {
      final id = rawId.trim();
      if (id.isEmpty) continue;

      String? placeName;
      String? mandalName;
      String? pinCode;
      String? scheduledArrival;
      String? scheduledDeparture;
      String? actualArrival;
      String? actualDeparture;
      String? eta;
      bool isSkipped = false;

      final place = _placeRepository.getPlaceById(id);
      final secondaryStop = _placeRepository.getSecondaryStopById(id);
      final meta = enrichedStopMetadata?[id];

      String resolvedSource;

      if (place != null) {
        placeName = place.placeName;
        mandalName = place.mandalName;
        pinCode = place.pinCode;
        resolvedSource = place.resolutionSource;
      } else if (secondaryStop != null) {
        placeName = secondaryStop.placeName;
        mandalName = secondaryStop.mandalName;
        pinCode = secondaryStop.pinCode;
        resolvedSource = 'secondaryStopDirectory';
      } else if (meta != null && meta.placeName.isNotEmpty) {
        placeName = meta.placeName;
        mandalName = meta.mandalName;
        pinCode = meta.pinCode;
        scheduledArrival = meta.scheduledArrival;
        scheduledDeparture = meta.scheduledDeparture;
        actualArrival = meta.actualArrival;
        actualDeparture = meta.actualDeparture;
        eta = meta.eta;
        isSkipped = meta.isSkipped;
        resolvedSource = 'route metadata';
      } else if (enrichedStopNames != null &&
          enrichedStopNames.containsKey(id) &&
          enrichedStopNames[id]!.trim().isNotEmpty) {
        placeName = enrichedStopNames[id]!.trim();
        resolvedSource = 'route metadata';
      } else {
        placeName = 'Intermediate stop';
        resolvedSource = 'unresolved';
      }

      fullStops.add(
        ApsrtcRouteStop(
          stationId: id,
          placeName: placeName,
          mandalName: mandalName,
          pinCode: pinCode,
          sequenceNo: seq++,
          scheduledArrival: scheduledArrival,
          scheduledDeparture: scheduledDeparture,
          actualArrival: actualArrival,
          actualDeparture: actualDeparture,
          eta: eta,
          isSkipped: isSkipped,
          resolvedSource: resolvedSource,
        ),
      );
    }

    if (fullStops.isEmpty) {
      final fallbackStops = _createFallbackStops(
        fromStation: fromStation,
        toStation: toStation,
        fromName: fromName,
        toName: toName,
      );
      final result = ApsrtcRouteSegmentResult.direct(
        serviceDocId: serviceDocId,
        stops: fallbackStops,
      );
      _cache[cacheKey] = result;
      return result;
    }

    final result = _sliceSegment(
      serviceDocId: serviceDocId,
      fullStops: fullStops,
      fromStation: fromStation,
      toStation: toStation,
      fromName: fromName,
      toName: toName,
    );

    _cache[cacheKey] = result;
    return result;
  }

  ApsrtcRouteSegmentResult _sliceSegment({
    required String serviceDocId,
    required List<ApsrtcRouteStop> fullStops,
    ApsrtcStation? fromStation,
    ApsrtcStation? toStation,
    String? fromName,
    String? toName,
  }) {
    int fromIdx = -1;
    int toIdx = -1;

    final targetFromId = fromStation?.placeId ?? fromStation?.linkPlaceId;
    final targetFromName = (fromStation?.placeName ?? fromName ?? '')
        .toUpperCase()
        .trim();

    final targetToId = toStation?.placeId ?? toStation?.linkPlaceId;
    final targetToName = (toStation?.placeName ?? toName ?? '')
        .toUpperCase()
        .trim();

    for (int i = 0; i < fullStops.length; i++) {
      final stop = fullStops[i];
      final stopNameUpper = stop.placeName.toUpperCase().trim();

      if (fromIdx == -1) {
        if (targetFromId != null && stop.stationId == targetFromId) {
          fromIdx = i;
        } else if (targetFromName.isNotEmpty &&
            stopNameUpper == targetFromName) {
          fromIdx = i;
        }
      }

      if (toIdx == -1) {
        if (targetToId != null && stop.stationId == targetToId) {
          toIdx = i;
        } else if (targetToName.isNotEmpty && stopNameUpper == targetToName) {
          toIdx = i;
        }
      }
    }

    final bool isValidSegment =
        (fromIdx != -1 && toIdx != -1 && fromIdx < toIdx);

    // Fallbacks if not matched by ID/name
    if (fromIdx == -1) fromIdx = 0;
    if (toIdx == -1) toIdx = fullStops.length - 1;

    if (!isValidSegment) {
      fromIdx = 0;
      toIdx = fullStops.length - 1;
    }

    final List<ApsrtcRouteStop> markedFullStops = [];
    for (int i = 0; i < fullStops.length; i++) {
      final isBoarding = (i == fromIdx);
      final isDrop = (i == toIdx);
      final isInter = (i > fromIdx && i < toIdx);

      markedFullStops.add(
        fullStops[i].copyWith(
          isBoardingStop: isBoarding,
          isDropStop: isDrop,
          isIntermediate: isInter,
        ),
      );
    }

    final visibleSegment = markedFullStops.sublist(fromIdx, toIdx + 1);
    final intermediateSegment = (fromIdx + 1 < toIdx)
        ? markedFullStops.sublist(fromIdx + 1, toIdx)
        : <ApsrtcRouteStop>[];

    String summary;
    if (intermediateSegment.isEmpty) {
      summary = 'Direct service';
    } else if (intermediateSegment.length <= 3) {
      final names = intermediateSegment.map((s) => s.placeName).join(', ');
      summary = 'Via $names';
    } else {
      final firstTwo = intermediateSegment
          .take(2)
          .map((s) => s.placeName)
          .join(', ');
      final remaining = intermediateSegment.length - 2;
      summary = 'Via $firstTwo +$remaining more';
    }

    return ApsrtcRouteSegmentResult(
      serviceDocId: serviceDocId,
      fullRouteStops: markedFullStops,
      visibleSegmentStops: visibleSegment,
      intermediateStops: intermediateSegment,
      viaSummary: summary,
      fromIndex: fromIdx,
      toIndex: toIdx,
      isValidSegment: isValidSegment,
      isDirectService: intermediateSegment.isEmpty,
    );
  }

  Future<String?> _fetchWayPointStringFromFirestore(String serviceDocId) async {
    try {
      final url = Uri.parse('$firestoreBaseUrl/$serviceDocId');
      final resp = await _client.get(url).timeout(const Duration(seconds: 5));

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final fields = decoded['fields'] as Map<String, dynamic>? ?? {};
        final wayPointMap = fields['wayPointString'] as Map<String, dynamic>?;
        if (wayPointMap != null && wayPointMap.containsKey('stringValue')) {
          return wayPointMap['stringValue']?.toString();
        }
      }
    } catch (_) {
      // Silently catch network errors
    }
    return null;
  }

  List<ApsrtcRouteStop> _createFallbackStops({
    ApsrtcStation? fromStation,
    ApsrtcStation? toStation,
    String? fromName,
    String? toName,
  }) {
    final startName = fromStation?.placeName ?? fromName ?? 'START';
    final startId = fromStation?.placeId ?? 'src';

    final endName = toStation?.placeName ?? toName ?? 'DESTINATION';
    final endId = toStation?.placeId ?? 'dest';

    return [
      ApsrtcRouteStop(
        stationId: startId,
        placeName: startName,
        sequenceNo: 1,
        isBoardingStop: true,
      ),
      ApsrtcRouteStop(
        stationId: endId,
        placeName: endName,
        sequenceNo: 2,
        isDropStop: true,
      ),
    ];
  }
}
