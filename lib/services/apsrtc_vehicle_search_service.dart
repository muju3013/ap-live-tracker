import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'apsrtc_current_vehicle_trip_resolver.dart';

class ApsrtcVehicleSearchException implements Exception {
  final String message;
  final int? statusCode;
  final String? exceptionType;

  ApsrtcVehicleSearchException(
    this.message, {
    this.statusCode,
    this.exceptionType,
  });

  @override
  String toString() => message;
}

class ApsrtcVehicleSearchResult {
  final String vehicleNumber;
  final String serviceDocId;
  final String oprsNo;
  final String serviceType;
  final String depotName;
  final bool isOnline;
  final int refreshedAt;
  final String locationTime;
  final String tripStatus;
  final bool isAbnormalEndTrip;

  const ApsrtcVehicleSearchResult({
    required this.vehicleNumber,
    required this.serviceDocId,
    required this.oprsNo,
    required this.serviceType,
    required this.depotName,
    required this.isOnline,
    required this.refreshedAt,
    required this.locationTime,
    this.tripStatus = '1',
    this.isAbnormalEndTrip = false,
  });

  factory ApsrtcVehicleSearchResult.fromFirestoreQueryJson(
    Map<String, dynamic> docJson,
  ) {
    final String name = docJson['name'] as String? ?? '';
    final serviceDocId = name.split('/').last;

    final fields = docJson['fields'] as Map<String, dynamic>? ?? {};

    String parseString(dynamic map) {
      if (map is Map && map.containsKey('stringValue')) {
        return map['stringValue']?.toString() ?? '';
      }
      return '';
    }

    int parseInt(dynamic map) {
      if (map is Map) {
        if (map.containsKey('integerValue')) {
          return int.tryParse(map['integerValue'].toString()) ?? 0;
        }
        if (map.containsKey('stringValue')) {
          return int.tryParse(map['stringValue'].toString()) ?? 0;
        }
      }
      return 0;
    }

    bool parseBool(dynamic map) {
      if (map is Map) {
        final val =
            map['stringValue'] ?? map['integerValue'] ?? map['booleanValue'];
        if (val is bool) return val;
        final s = val?.toString().toLowerCase().trim();
        return s == '1' || s == 'true';
      }
      return false;
    }

    return ApsrtcVehicleSearchResult(
      vehicleNumber: parseString(fields['vehicleNumber']),
      serviceDocId: serviceDocId,
      oprsNo: parseString(fields['oprsNo']),
      serviceType: parseString(fields['serviceType']),
      depotName: parseString(fields['depotName']),
      isOnline: parseBool(fields['isOnline']),
      refreshedAt: parseInt(fields['refreshedAt']),
      locationTime: parseString(fields['locationTime']),
      tripStatus: parseString(fields['tripStatus']).isNotEmpty
          ? parseString(fields['tripStatus'])
          : '1',
      isAbnormalEndTrip: parseBool(fields['isAbnormalEndTrip']),
    );
  }

  String get routeSummary =>
      depotName.isNotEmpty ? '$depotName Depot' : 'APSRTC Service';
}

class ApsrtcVehicleSearchService {
  static const String queryEndpoint =
      'https://firestore.googleapis.com/v1/projects/apsrtc-uts-prod/databases/(default)/documents:runQuery';

  final http.Client _client;

  ApsrtcVehicleSearchService({http.Client? client})
    : _client = client ?? http.Client();

  /// Clean vehicle number (e.g. "AP 39 X 6803" -> "AP39X6803")
  static String cleanVehicleNumber(String raw) {
    return ApsrtcCurrentVehicleTripResolver.normalizeVehicleNumber(raw);
  }

  /// Searches active APSRTC service(s) by vehicle number in Firestore tracking.
  Future<List<ApsrtcVehicleSearchResult>> searchVehicle(
    String rawVehicleNumber, {
    DateTime? currentTime,
  }) async {
    final cleaned = cleanVehicleNumber(rawVehicleNumber);
    if (cleaned.isEmpty) return [];

    final candidates = <String>{cleaned, rawVehicleNumber.trim().toUpperCase()};
    final List<ApsrtcVehicleSearchResult> allResults = [];
    Object? lastError;
    bool requestSucceeded = false;

    for (final vehNum in candidates) {
      final payload = {
        "structuredQuery": {
          "from": [
            {"collectionId": "trackingDetailsV2"},
          ],
          "where": {
            "fieldFilter": {
              "field": {"fieldPath": "vehicleNumber"},
              "op": "EQUAL",
              "value": {"stringValue": vehNum},
            },
          },
        },
      };

      try {
        debugPrint(
          '[ApsrtcVehicleSearchService] POST $queryEndpoint for vehicle $vehNum',
        );
        final response = await _client
            .post(
              Uri.parse(queryEndpoint),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 10));

        debugPrint(
          '[ApsrtcVehicleSearchService] HTTP Status: ${response.statusCode}, Body Length: ${response.body.length}',
        );

        if (response.statusCode == 200) {
          requestSucceeded = true;
          final List decoded = jsonDecode(response.body);
          for (final item in decoded) {
            if (item is Map && item.containsKey('document')) {
              final doc = item['document'] as Map<String, dynamic>;
              final result = ApsrtcVehicleSearchResult.fromFirestoreQueryJson(
                doc,
              );
              if (result.serviceDocId.isNotEmpty &&
                  !allResults.any(
                    (r) => r.serviceDocId == result.serviceDocId,
                  )) {
                allResults.add(result);
              }
            }
          }
        } else {
          lastError = ApsrtcVehicleSearchException(
            'Firestore HTTP status code ${response.statusCode}',
            statusCode: response.statusCode,
          );
        }
      } catch (e) {
        final isTimeout = e is TimeoutException;
        debugPrint(
          '[ApsrtcVehicleSearchService] Exception: type: ${e.runtimeType}, Timeout: $isTimeout, Message: $e',
        );
        lastError = e;
      }

      if (allResults.isNotEmpty) break;
    }

    if (!requestSucceeded && allResults.isEmpty && lastError != null) {
      if (lastError is ApsrtcVehicleSearchException) throw lastError;
      throw ApsrtcVehicleSearchException(
        'Vehicle search request failed: $lastError',
        exceptionType: lastError.runtimeType.toString(),
      );
    }

    if (allResults.isEmpty) return [];

    // Use ApsrtcCurrentVehicleTripResolver to evaluate and rank all candidate documents
    final evaluated = ApsrtcCurrentVehicleTripResolver.evaluateCandidates(
      allResults,
      currentTime: currentTime,
    );

    if (evaluated.isEmpty) return [];

    // Check if the top evaluated candidate is distinctly better than others
    final topCandidate = evaluated.first;
    if (evaluated.length == 1) {
      return [topCandidate.result];
    }

    final secondCandidate = evaluated[1];
    // If top candidate has higher category score or is today vs not today, it is the single best match
    if (topCandidate.categoryScore > secondCandidate.categoryScore ||
        (topCandidate.isToday && !secondCandidate.isToday)) {
      return [topCandidate.result];
    }

    // Otherwise return top candidates list if true ambiguity exists
    return evaluated.map((e) => e.result).toList();
  }
}
