import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

/// Lightweight HTTP abstraction for testability.
class GeocodingHttpResponse {
  final int statusCode;
  final String body;
  const GeocodingHttpResponse(this.statusCode, this.body);
}

abstract class GeocodingHttpClient {
  Future<GeocodingHttpResponse> get(Uri url);
}

class _RealHttpClient implements GeocodingHttpClient {
  @override
  Future<GeocodingHttpResponse> get(Uri url) async {
    final response = await http.get(url);
    return GeocodingHttpResponse(response.statusCode, response.body);
  }
}

class GeocodingSuggestion {
  final String placeName;
  final String shortName;
  final double latitude;
  final double longitude;

  const GeocodingSuggestion({
    required this.placeName,
    required this.shortName,
    required this.latitude,
    required this.longitude,
  });

  factory GeocodingSuggestion.fromJson(Map<String, dynamic> json) {
    final center = json['center'] as List<dynamic>;
    return GeocodingSuggestion(
      placeName: json['place_name'] as String? ?? '',
      shortName: json['text'] as String? ?? '',
      longitude: (center[0] as num).toDouble(),
      latitude: (center[1] as num).toDouble(),
    );
  }
}

class GeocodingService {
  final String accessToken;
  final GeocodingHttpClient _client;

  GeocodingService({
    required this.accessToken,
    GeocodingHttpClient? httpClient,
  }) : _client = httpClient ?? _RealHttpClient();

  Future<List<GeocodingSuggestion>> autocomplete(String query) async {
    if (query.trim().isEmpty) return [];

    final encoded = Uri.encodeComponent(query.trim());
    final url = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/$encoded.json'
      '?access_token=$accessToken'
      '&autocomplete=true'
      '&limit=5'
      '&types=address,place,postcode',
    );

    try {
      final response = await _client.get(url);
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>? ?? [];
      return features
          .map((f) =>
              GeocodingSuggestion.fromJson(f as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Haversine distance in kilometers between two lat/lng points.
  static double haversineDistance(
    double lat1, double lon1, double lat2, double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;
}
