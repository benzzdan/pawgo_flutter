import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/models/mock_data.dart';

void main() {
  group('Walker filter logic', () {
    final walkers = [
      const Walker(
        id: 'w1',
        userId: 'u1',
        name: 'Alice',
        rating: 4.8,
        totalWalks: 50,
        isEnabled: true,
        backgroundChecked: true,
      ),
      const Walker(
        id: 'w2',
        userId: 'u2',
        name: 'Bob',
        rating: 4.2,
        totalWalks: 20,
        isEnabled: true,
      ),
      const Walker(
        id: 'w3',
        userId: 'u3',
        name: 'Carol',
        rating: 4.9,
        totalWalks: 100,
        isEnabled: false,
      ),
      const Walker(
        id: 'w4',
        userId: 'u4',
        name: 'Dave',
        rating: 4.5,
        totalWalks: 30,
        isEnabled: true,
      ),
    ];

    test('all filter returns all walkers', () {
      final filtered = applyWalkerFilter(walkers, 'all');
      expect(filtered, hasLength(4));
    });

    test('available filter returns only enabled walkers', () {
      final filtered = applyWalkerFilter(walkers, 'available');
      expect(filtered.every((w) => w.isEnabled), isTrue);
      expect(filtered, hasLength(3));
    });

    test('top_rated filter returns walkers with rating >= 4.5 sorted desc', () {
      final filtered = applyWalkerFilter(walkers, 'top_rated');
      // Alice 4.8, Carol 4.9, Dave 4.5 — all >= 4.5
      expect(filtered, hasLength(3));
      // Sorted descending by rating
      expect(filtered[0].name, 'Carol'); // 4.9
      expect(filtered[1].name, 'Alice'); // 4.8
      expect(filtered[2].name, 'Dave'); // 4.5
    });
  });
}

/// Pure function for filtering walkers client-side.
/// This mirrors the logic that will live in find_screen.dart.
List<Walker> applyWalkerFilter(List<Walker> walkers, String filter) {
  switch (filter) {
    case 'available':
      return walkers.where((w) => w.isEnabled).toList();
    case 'top_rated':
      final filtered = walkers.where((w) => w.rating >= 4.5).toList();
      filtered.sort((a, b) => b.rating.compareTo(a.rating));
      return filtered;
    default:
      return walkers;
  }
}
