import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/models/dog.dart';
import 'package:pawgo/models/temperament.dart';
import 'package:pawgo/services/booking_rules.dart';

Dog _dog({
  required Temperament t,
  String vaxStatus = 'approved',
  DateTime? vaxExp,
}) => Dog(
      id: 'd',
      ownerId: 'o',
      name: 'X',
      breed: 'X',
      temperament: t,
      vaccinationStatus: vaxStatus,
      vaccinationExpiresAt: vaxExp,
    );

void main() {
  group('vaccination gate', () {
    test('blocks when not approved', () {
      final r = evaluateBookingRules(
        dog: _dog(t: Temperament.calm, vaxStatus: 'pending_review'),
        walkerExperienceYears: 5,
        walkType: WalkType.solo,
      );
      expect(r.allowed, isFalse);
      expect(r.errorCodeKey, 'bookingErrorVaccinationRequired');
    });

    test('allows when approved + not expired', () {
      final r = evaluateBookingRules(
        dog: _dog(t: Temperament.calm),
        walkerExperienceYears: 5,
        walkType: WalkType.solo,
      );
      expect(r.allowed, isTrue);
    });
  });

  group('temperament gate', () {
    test('aggressive requires experienced walker + solo', () {
      expect(
        evaluateBookingRules(
          dog: _dog(t: Temperament.aggressive),
          walkerExperienceYears: 2,
          walkType: WalkType.solo,
        ).errorCodeKey,
        'bookingErrorAggressiveNeedsExperienced',
      );

      expect(
        evaluateBookingRules(
          dog: _dog(t: Temperament.aggressive),
          walkerExperienceYears: 5,
          walkType: WalkType.group,
        ).errorCodeKey,
        'bookingErrorReactiveNoGroup',
      );

      expect(
        evaluateBookingRules(
          dog: _dog(t: Temperament.aggressive),
          walkerExperienceYears: 5,
          walkType: WalkType.solo,
        ).allowed,
        isTrue,
      );
    });

    test('reactive and passive_aggressive block group', () {
      for (final t in [Temperament.reactive, Temperament.passiveAggressive]) {
        expect(
          evaluateBookingRules(
            dog: _dog(t: t),
            walkerExperienceYears: 0,
            walkType: WalkType.group,
          ).errorCodeKey,
          'bookingErrorReactiveNoGroup',
        );

        expect(
          evaluateBookingRules(
            dog: _dog(t: t),
            walkerExperienceYears: 0,
            walkType: WalkType.solo,
          ).allowed,
          isTrue,
        );
      }
    });

    test('other moods allow group', () {
      for (final t in [
        Temperament.calm,
        Temperament.playful,
        Temperament.shy,
        Temperament.anxious,
      ]) {
        expect(
          evaluateBookingRules(
            dog: _dog(t: t),
            walkerExperienceYears: 0,
            walkType: WalkType.group,
          ).allowed,
          isTrue,
        );
      }
    });
  });
}
