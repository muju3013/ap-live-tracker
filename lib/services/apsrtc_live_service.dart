import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bus_live_location.dart';

class ApsrtcLiveService {
  static const String trackingBaseUrl =
      'https://firestore.googleapis.com/v1/projects/apsrtc-uts-prod/databases/(default)/documents/trackingDetailsV2';
  static const String detailsBaseUrl =
      'https://firestore.googleapis.com/v1/projects/apsrtc-uts-prod/databases/(default)/documents/serviceDetails';

  final http.Client _client;

  ApsrtcLiveService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches the live bus tracking details and service details for a dynamic [serviceDocId] from Firestore.
  Future<BusLiveLocation> fetchLiveLocation({
    required String serviceDocId,
    String? customUrl,
  }) async {
    final trackingUrlString = customUrl ?? '$trackingBaseUrl/$serviceDocId';
    final detailsUrlString = '$detailsBaseUrl/$serviceDocId';

    try {
      final responses = await Future.wait([
        _client
            .get(Uri.parse(trackingUrlString))
            .timeout(const Duration(seconds: 10)),
        _client
            .get(Uri.parse(detailsUrlString))
            .timeout(const Duration(seconds: 5))
            .catchError((_) => http.Response('', 404)),
      ]);

      final trackingResponse = responses[0];
      final detailsResponse = responses[1];

      if (trackingResponse.statusCode == 200) {
        final Map<String, dynamic> trackingJson = jsonDecode(
          trackingResponse.body,
        );
        Map<String, dynamic>? serviceDetailsJson;
        if (detailsResponse.statusCode == 200 &&
            detailsResponse.body.isNotEmpty) {
          try {
            serviceDetailsJson = jsonDecode(detailsResponse.body);
          } catch (_) {}
        }
        return BusLiveLocation.fromFirestoreJson(
          trackingJson,
          serviceDetailsJson: serviceDetailsJson,
        );
      } else {
        throw HttpException(
          'HTTP GET failed with status code ${trackingResponse.statusCode}',
          statusCode: trackingResponse.statusCode,
        );
      }
    } catch (e) {
      if (e is HttpException) rethrow;
      throw Exception('Failed to fetch live bus location: $e');
    }
  }
}

class HttpException implements Exception {
  final String message;
  final int statusCode;

  HttpException(this.message, {required this.statusCode});

  @override
  String toString() => message;
}
