import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/models/mock_data.dart';
import 'package:pawgo/services/geocoding_service.dart';

/// Advanced filter model — mirrors what will be in find_screen.dart.
class AdvancedFilters {
  final double? maxDistanceKm;
  final double? minRate;
  final double? maxRate;
  final int? minExperience;
  final bool? backgroundChecked;

  const AdvancedFilters({
    this.maxDistanceKm,
    this.minRate,
    this.maxRate,
    this.minExperience,
    this.backgroundChecked,
  });

  int get activeCount {
    int count = 0;
    if (maxDistanceKm != null) count++;
    if (minRate != null || maxRate != null) count++;
    if (minExperience != null) count++;
    if (backgroundChecked == true) count++;
    return count;
  }

  bool get hasActiveFilters => activeCount > 0;
}

List<Walker> applyAdvancedFilters(
  List<Walker> walkers,
  AdvancedFilters filters, {
  double? searchLat,
  double? searchLng,
}) {
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
  // Distance filter would use GeocodingService.haversineDistance
  // but requires walker location data — skip in client-side filtering

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

    test('activeCount counts each active filter', () {
      const filters = AdvancedFilters(
        maxDistanceKm: 10,
        minRate: 100,
        maxRate: 200,
        backgroundChecked: true,
      );
      // maxDistanceKm: 1, rate range: 1 (min+max count as 1), backgroundChecked: 1
      expect(filters.activeCount, 3);
      expect(filters.hasActiveFilters, isTrue);
    });

    test('minExperience filter counts', () {
      const filters = AdvancedFilters(minExperience: 2);
      expect(filters.activeCount, 1);
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
