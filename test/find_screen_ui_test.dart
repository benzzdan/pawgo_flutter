import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/screens/find_screen.dart';
import 'package:pawgo/models/mock_data.dart';

void main() {
  group('FindScreen UI spacing constants', () {
    test('walker card separator is at least 12px', () {
      // The ListView.separated uses SizedBox(height: walkerCardSpacing)
      // Acceptance criteria: minimum 12px
      expect(FindScreenLayout.walkerCardSpacing, greaterThanOrEqualTo(12.0));
    });

    test('search bar vertical padding is at least 16px', () {
      expect(FindScreenLayout.searchBarTopPadding, greaterThanOrEqualTo(16.0));
      expect(
          FindScreenLayout.searchBarBottomPadding, greaterThanOrEqualTo(16.0));
    });

    test('filter button horizontal spacing exists', () {
      expect(
          FindScreenLayout.filterButtonSpacing, greaterThanOrEqualTo(8.0));
    });

    test('screen horizontal padding is at least 16px', () {
      expect(
          FindScreenLayout.horizontalPadding, greaterThanOrEqualTo(16.0));
    });
  });

  group('Walker card hierarchy', () {
    test('name font is larger than rating/walks', () {
      expect(FindScreenLayout.nameFontSize,
          greaterThan(FindScreenLayout.ratingFontSize));
    });

    test('rating/walks font is larger than bio', () {
      expect(FindScreenLayout.ratingFontSize,
          greaterThan(FindScreenLayout.bioFontSize));
    });

    test('name font weight is bold (w800)', () {
      expect(FindScreenLayout.nameFontWeight.index,
          greaterThanOrEqualTo(7)); // w800 = index 7
    });
  });
}
