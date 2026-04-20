import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/utils/distance_utils.dart';

void main() {
  group('calculateDistanceMeters', () {
    test('returns ~0 for same point', () {
      final distance = calculateDistanceMeters(19.4326, -99.1332, 19.4326, -99.1332);
      expect(distance, closeTo(0, 0.1));
    });

    test('returns ~111,195 m for 1 degree latitude difference', () {
      // 1 degree of latitude is approximately 111,195 meters
      final distance = calculateDistanceMeters(0, 0, 1, 0);
      expect(distance, closeTo(111195, 500));
    });

    test('returns reasonable distance for known coordinates', () {
      // Mexico City (Zócalo) to Chapultepec Castle: ~4.3 km
      final distance = calculateDistanceMeters(
        19.4326, -99.1332, // Zócalo
        19.4204, -99.1818, // Chapultepec
      );
      expect(distance, closeTo(5300, 1000));
    });
  });

  group('formatDistanceBadge', () {
    test('returns "Walker is 350 m away" for 350 meters', () {
      expect(formatDistanceBadge(350), 'Walker is 350 m away');
    });

    test('returns "Walker is almost here!" for distances <= 200 m', () {
      expect(formatDistanceBadge(200), 'Walker is almost here!');
      expect(formatDistanceBadge(180), 'Walker is almost here!');
      expect(formatDistanceBadge(50), 'Walker is almost here!');
      expect(formatDistanceBadge(0), 'Walker is almost here!');
    });

    test('returns "Walker is 1.5 km away" for 1500 meters', () {
      expect(formatDistanceBadge(1500), 'Walker is 1.5 km away');
    });

    test('returns km format for distances >= 1000 m', () {
      expect(formatDistanceBadge(1000), 'Walker is 1.0 km away');
      expect(formatDistanceBadge(2300), 'Walker is 2.3 km away');
    });

    test('returns meters for distances between 201 and 999', () {
      expect(formatDistanceBadge(201), 'Walker is 201 m away');
      expect(formatDistanceBadge(999), 'Walker is 999 m away');
    });
  });
}
