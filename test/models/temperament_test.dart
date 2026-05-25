import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/models/temperament.dart';

void main() {
  test('Temperament round-trips through its database string', () {
    for (final t in Temperament.values) {
      expect(Temperament.fromDb(t.dbValue), t);
    }
  });

  test('aggressive flag is true only for the right values', () {
    expect(Temperament.aggressive.requiresExperiencedWalker, isTrue);
    expect(Temperament.calm.requiresExperiencedWalker, isFalse);
  });

  test('blocksGroupWalks is true for reactive and passive_aggressive and aggressive', () {
    expect(Temperament.reactive.blocksGroupWalks, isTrue);
    expect(Temperament.passiveAggressive.blocksGroupWalks, isTrue);
    expect(Temperament.aggressive.blocksGroupWalks, isTrue);
    expect(Temperament.calm.blocksGroupWalks, isFalse);
  });
}
