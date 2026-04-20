import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/utils/enroute_map_helpers.dart';

void main() {
  group('shouldShowEnRouteMap', () {
    test('returns true for confirmed', () {
      expect(shouldShowEnRouteMap('confirmed'), isTrue);
    });

    test('returns true for walker_en_route', () {
      expect(shouldShowEnRouteMap('walker_en_route'), isTrue);
    });

    test('returns false for walk_started', () {
      expect(shouldShowEnRouteMap('walk_started'), isFalse);
    });

    test('returns false for pending', () {
      expect(shouldShowEnRouteMap('pending'), isFalse);
    });

    test('returns false for pending_walker_acceptance', () {
      expect(shouldShowEnRouteMap('pending_walker_acceptance'), isFalse);
    });

    test('returns false for walk_completed', () {
      expect(shouldShowEnRouteMap('walk_completed'), isFalse);
    });

    test('returns false for cancelled', () {
      expect(shouldShowEnRouteMap('cancelled'), isFalse);
    });

    test('returns false for empty string', () {
      expect(shouldShowEnRouteMap(''), isFalse);
    });
  });

  group('enRouteMapStatuses', () {
    test('contains exactly confirmed and walker_en_route', () {
      expect(enRouteMapStatuses, containsAll(['confirmed', 'walker_en_route']));
      expect(enRouteMapStatuses.length, 2);
    });
  });
}
