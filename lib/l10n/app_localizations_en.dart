// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Pawgo';

  @override
  String get moodCalm => 'Calm';

  @override
  String get moodPlayful => 'Playful';

  @override
  String get moodShy => 'Shy';

  @override
  String get moodAnxious => 'Anxious';

  @override
  String get moodPassiveAggressive => 'Passive-aggressive';

  @override
  String get moodReactive => 'Reactive to dogs';

  @override
  String get moodAggressive => 'Aggressive';

  @override
  String get vaccinationPending => 'Pending review';

  @override
  String get vaccinationApproved => 'Approved';

  @override
  String get vaccinationRejected => 'Rejected';

  @override
  String get vaccinationExpired => 'Expired';

  @override
  String get bookingErrorAggressiveNeedsExperienced =>
      'This dog requires an experienced walker (3+ years).';

  @override
  String get bookingErrorReactiveNoGroup => 'This dog can\'t join group walks.';

  @override
  String get bookingErrorVaccinationRequired =>
      'Vaccination card must be approved before booking.';
}
