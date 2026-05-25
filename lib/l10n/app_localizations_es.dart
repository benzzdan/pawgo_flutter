// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Pawgo';

  @override
  String get moodCalm => 'Tranquilo';

  @override
  String get moodPlayful => 'Juguetón';

  @override
  String get moodShy => 'Tímido';

  @override
  String get moodAnxious => 'Ansioso';

  @override
  String get moodPassiveAggressive => 'Pasivo-agresivo';

  @override
  String get moodReactive => 'Reactivo con otros perros';

  @override
  String get moodAggressive => 'Agresivo';

  @override
  String get vaccinationPending => 'Pendiente de revisión';

  @override
  String get vaccinationApproved => 'Aprobada';

  @override
  String get vaccinationRejected => 'Rechazada';

  @override
  String get vaccinationExpired => 'Vencida';

  @override
  String get bookingErrorAggressiveNeedsExperienced =>
      'Este perro necesita un paseador con experiencia (3+ años).';

  @override
  String get bookingErrorReactiveNoGroup =>
      'Este perro no puede unirse a paseos grupales.';

  @override
  String get bookingErrorVaccinationRequired =>
      'La cartilla de vacunación debe estar aprobada antes de reservar.';
}
