import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/services/geocoding_service.dart';

// --- GeocodingService unit tests ---

/// Mock HTTP client for testing geocoding without network calls.
class MockHttpClient implements GeocodingHttpClient {
  final Map<String, String> responses = {};
  String? lastRequestedUrl;

  void stubResponse(String urlContains, String body) {
    responses[urlContains] = body;
  }

  @override
  Future<GeocodingHttpResponse> get(Uri url) async {
    lastRequestedUrl = url.toString();
    for (final entry in responses.entries) {
      if (url.toString().contains(entry.key)) {
        return GeocodingHttpResponse(200, entry.value);
      }
    }
    return GeocodingHttpResponse(404, '{"message":"Not Found"}');
  }
}

void main() {
  group('GeocodingService', () {
    late MockHttpClient mockClient;
    late GeocodingService service;

    setUp(() {
      mockClient = MockHttpClient();
      service = GeocodingService(
        accessToken: 'test_token',
        httpClient: mockClient,
      );
    });

    test('autocomplete returns parsed suggestions from Mapbox API', () async {
      mockClient.stubResponse('mapbox.places', '''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "place_name": "123 Main St, New York, NY 10001",
            "center": [-73.9857, 40.7484],
            "text": "123 Main St"
          },
          {
            "place_name": "123 Main Ave, Los Angeles, CA 90001",
            "center": [-118.2437, 34.0522],
            "text": "123 Main Ave"
          }
        ]
      }
      ''');

      final results = await service.autocomplete('123 Main');

      expect(results, hasLength(2));
      expect(results[0].placeName, '123 Main St, New York, NY 10001');
      expect(results[0].longitude, -73.9857);
      expect(results[0].latitude, 40.7484);
      expect(results[1].placeName, '123 Main Ave, Los Angeles, CA 90001');
    });

    test('autocomplete returns empty list for empty query', () async {
      final results = await service.autocomplete('');
      expect(results, isEmpty);
      expect(mockClient.lastRequestedUrl, isNull);
    });

    test('autocomplete returns empty list on API error', () async {
      // No stub → 404
      final results = await service.autocomplete('unknown');
      expect(results, isEmpty);
    });

    test('autocomplete URL includes access token and autocomplete param',
        () async {
      mockClient.stubResponse('mapbox.places',
          '{"type":"FeatureCollection","features":[]}');

      await service.autocomplete('test query');

      expect(mockClient.lastRequestedUrl, contains('access_token=test_token'));
      expect(mockClient.lastRequestedUrl, contains('autocomplete=true'));
      expect(mockClient.lastRequestedUrl, contains('limit=5'));
    });
  });

  group('GeocodingSuggestion', () {
    test('fromJson parses Mapbox feature correctly', () {
      final json = {
        'place_name': '456 Oak Rd, Chicago, IL 60601',
        'center': [-87.6298, 41.8781],
        'text': '456 Oak Rd',
      };

      final suggestion = GeocodingSuggestion.fromJson(json);

      expect(suggestion.placeName, '456 Oak Rd, Chicago, IL 60601');
      expect(suggestion.shortName, '456 Oak Rd');
      expect(suggestion.longitude, -87.6298);
      expect(suggestion.latitude, 41.8781);
    });
  });

  group('Proximity sorting', () {
    test('sortByProximity sorts walkers by distance from a point', () {
      // Simple haversine: NYC is closer to Philly than to LA
      final nyc = GeocodingSuggestion(
        placeName: 'NYC',
        shortName: 'NYC',
        latitude: 40.7128,
        longitude: -74.0060,
      );

      // Distances from NYC: Philly ~130km, Chicago ~1150km, LA ~3940km
      final distPhilly = GeocodingService.haversineDistance(
        nyc.latitude, nyc.longitude, 39.9526, -75.1652,
      );
      final distChicago = GeocodingService.haversineDistance(
        nyc.latitude, nyc.longitude, 41.8781, -87.6298,
      );
      final distLA = GeocodingService.haversineDistance(
        nyc.latitude, nyc.longitude, 34.0522, -118.2437,
      );

      expect(distPhilly, lessThan(distChicago));
      expect(distChicago, lessThan(distLA));
      // Rough magnitude check
      expect(distPhilly, closeTo(130, 20)); // ~130 km
      expect(distLA, closeTo(3940, 200)); // ~3940 km
    });
  });
}
