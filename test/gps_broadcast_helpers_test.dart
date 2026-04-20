import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/utils/gps_broadcast_helpers.dart';

void main() {
  group('shouldStartGpsBroadcast', () {
    test('returns true for confirmed', () {
      expect(shouldStartGpsBroadcast('confirmed'), isTrue);
    });

    test('returns true for walker_en_route', () {
      expect(shouldStartGpsBroadcast('walker_en_route'), isTrue);
    });

    test('returns true for walk_started', () {
      expect(shouldStartGpsBroadcast('walk_started'), isTrue);
    });

    test('returns false for pending', () {
      expect(shouldStartGpsBroadcast('pending'), isFalse);
    });

    test('returns false for pending_walker_acceptance', () {
      expect(shouldStartGpsBroadcast('pending_walker_acceptance'), isFalse);
    });

    test('returns false for walk_completed', () {
      expect(shouldStartGpsBroadcast('walk_completed'), isFalse);
    });

    test('returns false for cancelled', () {
      expect(shouldStartGpsBroadcast('cancelled'), isFalse);
    });

    test('returns false for empty string', () {
      expect(shouldStartGpsBroadcast(''), isFalse);
    });
  });

  group('gpsBroadcastActiveStatuses', () {
    test('contains exactly confirmed, walker_en_route, walk_started', () {
      expect(
        gpsBroadcastActiveStatuses,
        unorderedEquals(['confirmed', 'walker_en_route', 'walk_started']),
      );
    });
  });
}
