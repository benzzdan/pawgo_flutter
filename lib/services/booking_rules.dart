import 'package:pawgo/l10n/app_localizations.dart';
import 'package:pawgo/models/dog.dart';
import 'package:pawgo/models/temperament.dart';

/// Single-dog vs multi-dog group walk. Mirrors `public.bookings.walk_type`.
enum WalkType { solo, group }

/// Outcome of running the booking-rules engine over a (dog, walker, walk_type)
/// tuple. `errorCodeKey` is an i18n key — see [localizedRuleError].
class BookingRuleResult {
  final bool allowed;
  final String? errorCodeKey;
  const BookingRuleResult.ok()
      : allowed = true,
        errorCodeKey = null;
  const BookingRuleResult.deny(this.errorCodeKey) : allowed = false;
}

/// Walkers below this experience threshold cannot book aggressive dogs.
const int _kExperiencedYears = 3;

/// Pure rule engine used to gate booking creation. Mirrors the server-side
/// logic in `supabase/functions/create-booking/index.ts`.
///
/// Returns the first failing rule (vaccination is checked before
/// temperament). For aggressive dogs the order is:
///   1. walker must have >= 3 years of experience
///   2. walk_type must be solo
BookingRuleResult evaluateBookingRules({
  required Dog dog,
  required int walkerExperienceYears,
  required WalkType walkType,
}) {
  if (!dog.isVaccinationValid) {
    return const BookingRuleResult.deny('bookingErrorVaccinationRequired');
  }
  final temp = dog.temperament;
  if (temp == Temperament.aggressive) {
    if (walkerExperienceYears < _kExperiencedYears) {
      return const BookingRuleResult.deny(
        'bookingErrorAggressiveNeedsExperienced',
      );
    }
    if (walkType == WalkType.group) {
      return const BookingRuleResult.deny('bookingErrorReactiveNoGroup');
    }
    return const BookingRuleResult.ok();
  }
  if (temp != null && temp.blocksGroupWalks && walkType == WalkType.group) {
    return const BookingRuleResult.deny('bookingErrorReactiveNoGroup');
  }
  return const BookingRuleResult.ok();
}

/// Looks up an [AppLocalizations]-managed error string by the i18n key
/// returned in [BookingRuleResult.errorCodeKey]. Falls back to the key
/// itself for unknown keys so missing translations are still visible.
///
/// `flutter gen-l10n` doesn't expose a string-key lookup on the generated
/// class, so we maintain a small switch here. Add new cases whenever a
/// new rule key is introduced.
String localizedRuleError(AppLocalizations l, String key) {
  switch (key) {
    case 'bookingErrorVaccinationRequired':
      return l.bookingErrorVaccinationRequired;
    case 'bookingErrorAggressiveNeedsExperienced':
      return l.bookingErrorAggressiveNeedsExperienced;
    case 'bookingErrorReactiveNoGroup':
      return l.bookingErrorReactiveNoGroup;
    default:
      return key;
  }
}
