import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/services/walker_verification_service.dart';
import 'package:pawgo/theme/app_theme.dart';

/// Bilingual strings for the verification screen.
///
/// Pawgo's codebase doesn't have flutter_localizations + .arb files yet
/// (`spec features-may-25.md` "Codebase Reality Check" notes that i18n needs
/// to be scaffolded separately). To avoid blowing scope, we ship the strings
/// here as a typed map keyed by `Locale.languageCode` and read the active
/// locale via `Localizations.localeOf`. When the app moves to .arb files
/// later, this can be replaced with `AppLocalizations.of(context)` calls and
/// the keys are already named for that drop-in.
class _VerificationStrings {
  _VerificationStrings._(this._values);
  final Map<String, String> _values;

  String get title => _values['verificationTitle']!;
  String get startCta => _values['verificationStartCta']!;
  String get notStarted => _values['verificationStateNotStarted']!;
  String get sessionCreated => _values['verificationStateSessionCreated']!;
  String get submitted => _values['verificationStateSubmitted']!;
  String get verified => _values['verificationStateVerified']!;
  String get resubmission => _values['verificationStateResubmission']!;
  String get rejected => _values['verificationStateRejected']!;
  String get expired => _values['verificationStateExpired']!;
  String get abandoned => _values['verificationStateAbandoned']!;
  String get manualReview => _values['verificationStateManualReview']!;
  String get canceled => _values['verificationCanceled']!;
  String get errorGeneric => _values['verificationErrorGeneric']!;

  static const _es = <String, String>{
    'verificationTitle': 'Verificación de identidad',
    'verificationStartCta': 'Verificar mi identidad',
    'verificationStateNotStarted':
        'Necesitamos verificar tu identidad antes de aceptar paseos.',
    'verificationStateSessionCreated': 'Sesión lista — toca para empezar.',
    'verificationStateSubmitted': 'Enviado. Estamos revisando tus documentos.',
    'verificationStateVerified': 'Verificado ✓',
    'verificationStateResubmission':
        'Necesitamos una foto más clara. Intenta de nuevo.',
    'verificationStateRejected':
        'Tu verificación fue rechazada. Contacta a soporte.',
    'verificationStateExpired': 'La sesión expiró. Empieza de nuevo.',
    'verificationStateAbandoned': 'Te detuviste antes de terminar. Intenta de nuevo.',
    'verificationStateManualReview': 'En revisión manual — te avisaremos.',
    'verificationCanceled': 'Cancelaste la verificación.',
    'verificationErrorGeneric': 'Algo salió mal. Inténtalo de nuevo.',
  };

  static const _en = <String, String>{
    'verificationTitle': 'Identity verification',
    'verificationStartCta': 'Verify my identity',
    'verificationStateNotStarted':
        'We need to verify your identity before you can accept walks.',
    'verificationStateSessionCreated': 'Session ready — tap to start.',
    'verificationStateSubmitted': "Submitted. We're reviewing your documents.",
    'verificationStateVerified': 'Verified ✓',
    'verificationStateResubmission':
        'We need a clearer photo. Try again.',
    'verificationStateRejected':
        'Verification was declined. Contact support.',
    'verificationStateExpired': 'Session expired. Start again.',
    'verificationStateAbandoned': 'You stopped before finishing. Try again.',
    'verificationStateManualReview': "Under manual review — we'll notify you.",
    'verificationCanceled': 'You canceled the verification.',
    'verificationErrorGeneric': 'Something went wrong. Please try again.',
  };

  static _VerificationStrings of(BuildContext context) {
    final code = Localizations.maybeLocaleOf(context)?.languageCode ?? 'es';
    return _VerificationStrings._(code == 'en' ? _en : _es);
  }
}

class WalkerVerificationScreen extends StatefulWidget {
  const WalkerVerificationScreen({super.key});

  @override
  State<WalkerVerificationScreen> createState() => _WalkerVerificationScreenState();
}

class _WalkerVerificationScreenState extends State<WalkerVerificationScreen> {
  final _supa = Supabase.instance.client;
  late final WalkerVerificationService _svc = WalkerVerificationService(_supa);
  String _status = 'not_started';
  bool _busy = false;
  String? _flashMessage;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _subscribeToWalkerUpdates();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    final userId = _supa.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final row = await _supa
          .from('walkers')
          .select('verification_status')
          .eq('user_id', userId)
          .maybeSingle();
      if (row != null && mounted) {
        setState(() => _status = row['verification_status'] as String);
      }
    } catch (_) {
      // Silent — the UI defaults to `not_started`, which is a valid resting state.
    }
  }

  void _subscribeToWalkerUpdates() {
    final userId = _supa.auth.currentUser?.id;
    if (userId == null) return;
    _channel = _supa
        .channel('public:walkers:user_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'walkers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final next = payload.newRecord['verification_status'] as String?;
            if (next != null && mounted) {
              setState(() => _status = next);
            }
          },
        )
        ..subscribe();
  }

  Future<void> _start() async {
    final strings = _VerificationStrings.of(context);
    setState(() {
      _busy = true;
      _flashMessage = null;
    });
    try {
      final lang = Localizations.maybeLocaleOf(context)?.languageCode ?? 'es';
      final outcome = await _svc.startVerification(languageCode: lang);
      if (!mounted) return;
      switch (outcome.kind) {
        case VerificationOutcomeKind.submitted:
          setState(() => _status = 'submitted');
          break;
        case VerificationOutcomeKind.canceled:
          setState(() => _flashMessage = strings.canceled);
          break;
        case VerificationOutcomeKind.error:
          setState(() => _flashMessage = strings.errorGeneric);
          break;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      await _fetchStatus();
    }
  }

  String _stateLabel(_VerificationStrings s) {
    switch (_status) {
      case 'session_created':
        return s.sessionCreated;
      case 'submitted':
        return s.submitted;
      case 'verified':
        return s.verified;
      case 'resubmission_needed':
        return s.resubmission;
      case 'rejected':
        return s.rejected;
      case 'expired':
        return s.expired;
      case 'abandoned':
        return s.abandoned;
      case 'manual_review':
        return s.manualReview;
      case 'not_started':
      default:
        return s.notStarted;
    }
  }

  bool get _canStart =>
      _status != 'submitted' &&
      _status != 'verified' &&
      _status != 'manual_review';

  @override
  Widget build(BuildContext context) {
    final s = _VerificationStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          s.title,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _stateLabel(s),
              style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (_flashMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _flashMessage!,
                style: GoogleFonts.nunito(
                  color: AppColors.red500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const Spacer(),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _busy || !_canStart ? null : _start,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warmCaramel,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _busy
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.white,
                        ),
                      )
                    : Text(
                        s.startCta,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
