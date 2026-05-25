import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/models/mock_data.dart';
import 'package:pawgo/screens/find_screen.dart';

/// Re-implements the client-side filter logic that find_screen previously
/// used so we can keep these unit tests exercising the same predicates.
/// Once the server-side RPC takes over (PR B.4.5), find_screen no longer
/// runs these checks — but the model semantics (which fields count as
/// "active", how a range maps to one filter) still apply here.
List<Walker> applyAdvancedFilters(
  List<Walker> walkers,
  AdvancedFilters filters,
) {
  var result = walkers;
  if (filters.minRate != null) {
    result = result.where((w) => w.hourlyRateMxn >= filters.minRate!).toList();
  }
  if (filters.maxRate != null) {
    result = result.where((w) => w.hourlyRateMxn <= filters.maxRate!).toList();
  }
  if (filters.minExperience != null) {
    result = result
        .where((w) => w.experienceYears >= filters.minExperience!)
        .toList();
  }
  if (filters.backgroundChecked == true) {
    result = result.where((w) => w.backgroundChecked).toList();
  }
  return result;
}

void main() {
  final walkers = [
    const Walker(
      id: 'w1',
      userId: 'u1',
      name: 'Alice',
      rating: 4.8,
      hourlyRateMxn: 150,
      experienceYears: 3,
      backgroundChecked: true,
      isEnabled: true,
    ),
    const Walker(
      id: 'w2',
      userId: 'u2',
      name: 'Bob',
      rating: 4.2,
      hourlyRateMxn: 100,
      experienceYears: 1,
      backgroundChecked: false,
      isEnabled: true,
    ),
    const Walker(
      id: 'w3',
      userId: 'u3',
      name: 'Carol',
      rating: 4.9,
      hourlyRateMxn: 200,
      experienceYears: 5,
      backgroundChecked: true,
      isEnabled: true,
    ),
  ];

  group('AdvancedFilters', () {
    test('activeCount returns 0 for empty filters', () {
      const filters = AdvancedFilters();
      expect(filters.activeCount, 0);
      expect(filters.hasActiveFilters, isFalse);
    });

    test('activeCount counts each active filter (distance range counts as 1)', () {
      const filters = AdvancedFilters(
        minDistanceKm: 1,
        maxDistanceKm: 10,
        minRate: 100,
        maxRate: 200,
        backgroundChecked: true,
      );
      // distance range: 1, rate range: 1, backgroundChecked: 1 = 3
      expect(filters.activeCount, 3);
      expect(filters.hasActiveFilters, isTrue);
    });

    test('only maxDistanceKm (no min) still counts distance range as 1', () {
      const filters = AdvancedFilters(maxDistanceKm: 10);
      expect(filters.activeCount, 1);
    });

    test('only minDistanceKm (no max) still counts distance range as 1', () {
      const filters = AdvancedFilters(minDistanceKm: 2);
      expect(filters.activeCount, 1);
    });

    test('minExperience filter counts', () {
      const filters = AdvancedFilters(minExperience: 2);
      expect(filters.activeCount, 1);
    });

    test('onlyShowInRange alone does not count as an active filter', () {
      // The toggle only affects how NULL-distance walkers are handled — it
      // is not a filter on its own. Without min/max distance set, it is a
      // no-op and should not bump activeCount.
      const filters = AdvancedFilters(onlyShowInRange: true);
      expect(filters.activeCount, 0);
      expect(filters.hasActiveFilters, isFalse);
    });

    test('onlyShowInRange has a default of false', () {
      const filters = AdvancedFilters();
      expect(filters.onlyShowInRange, isFalse);
    });

    test('minDistanceKm defaults to null', () {
      const filters = AdvancedFilters();
      expect(filters.minDistanceKm, isNull);
    });
  });

  group('applyAdvancedFilters', () {
    test('no filters returns all walkers', () {
      final result = applyAdvancedFilters(walkers, const AdvancedFilters());
      expect(result, hasLength(3));
    });

    test('minRate filters out cheap walkers', () {
      final result = applyAdvancedFilters(
        walkers,
        const AdvancedFilters(minRate: 120),
      );
      expect(result, hasLength(2)); // Alice 150, Carol 200
      expect(result.every((w) => w.hourlyRateMxn >= 120), isTrue);
    });

    test('maxRate filters out expensive walkers', () {
      final result = applyAdvancedFilters(
        walkers,
        const AdvancedFilters(maxRate: 150),
      );
      expect(result, hasLength(2)); // Alice 150, Bob 100
    });

    test('minExperience filters inexperienced walkers', () {
      final result = applyAdvancedFilters(
        walkers,
        const AdvancedFilters(minExperience: 3),
      );
      expect(result, hasLength(2)); // Alice 3, Carol 5
    });

    test('backgroundChecked filters to verified only', () {
      final result = applyAdvancedFilters(
        walkers,
        const AdvancedFilters(backgroundChecked: true),
      );
      expect(result, hasLength(2)); // Alice, Carol
      expect(result.every((w) => w.backgroundChecked), isTrue);
    });

    test('multiple filters combine (AND logic)', () {
      final result = applyAdvancedFilters(
        walkers,
        const AdvancedFilters(
          minRate: 120,
          minExperience: 4,
          backgroundChecked: true,
        ),
      );
      expect(result, hasLength(1)); // Only Carol
      expect(result[0].name, 'Carol');
    });
  });
}
