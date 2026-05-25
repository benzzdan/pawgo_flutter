import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:veriff_flutter/veriff_flutter.dart' as veriff;

/// What happened when the walker ran the verification flow.
///
/// Note: `submitted` does NOT mean approved. The Veriff SDK reporting
/// `Status.done` only tells us the user finished the on-device flow — the
/// actual decision arrives on the server via webhook, so the UI should show
/// "awaiting review" until the walker row flips to `verified` (or another
/// terminal state).
enum VerificationOutcomeKind { submitted, canceled, error }

class VerificationOutcome {
  final VerificationOutcomeKind kind;
  final String? message;
  const VerificationOutcome._(this.kind, [this.message]);

  factory VerificationOutcome.submitted() =>
      const VerificationOutcome._(VerificationOutcomeKind.submitted);
  factory VerificationOutcome.canceled() =>
      const VerificationOutcome._(VerificationOutcomeKind.canceled);
  factory VerificationOutcome.error(String message) =>
      VerificationOutcome._(VerificationOutcomeKind.error, message);
}

class WalkerVerificationService {
  WalkerVerificationService(this._supa);
  final SupabaseClient _supa;

  /// Calls the `start-id-verification` Edge Function then launches the Veriff
  /// SDK with the returned `sessionUrl`. Caller decides what to do with the
  /// outcome (typically: refresh the walker's row from DB and show a state-
  /// machine UI).
  Future<VerificationOutcome> startVerification({String languageCode = 'es'}) async {
    final FunctionResponse res;
    try {
      res = await _supa.functions.invoke('start-id-verification');
    } catch (e) {
      return VerificationOutcome.error('start_session_failed: $e');
    }

    final data = res.data;
    if (data is! Map || data['sessionUrl'] is! String) {
      // Pull a server-supplied error.code if there is one.
      final err = (data is Map ? data['error'] : null);
      if (err is Map && err['code'] is String) {
        return VerificationOutcome.error(err['code'] as String);
      }
      return VerificationOutcome.error('invalid_session_response');
    }
    final sessionUrl = data['sessionUrl'] as String;

    final config = veriff.Configuration(
      sessionUrl,
      // The SDK names the locale parameter `languageLocale`. Plan referenced
      // `languageCode` — adapted to match SDK 4.6.0 surface.
      languageLocale: languageCode,
      branding: veriff.Branding(
        background: '#FFFFFF',
        primary: '#C07D4D', // AppColors.warmCaramel
        onPrimary: '#FFFFFF',
        success: '#1FAE5F',
        error: '#E53935',
        buttonRadius: 12,
      ),
    );

    try {
      final veriff.Result result = await veriff.Veriff().start(config);
      switch (result.status) {
        case veriff.Status.done:
          return VerificationOutcome.submitted();
        case veriff.Status.canceled:
          return VerificationOutcome.canceled();
        case veriff.Status.error:
          // `result.error` is a Veriff Error enum, not a string. Pass its
          // wire-form name to the UI so it can be logged or shown.
          final err = result.error;
          return VerificationOutcome.error(
            err == null ? 'unknown' : err.errorString(),
          );
      }
    } on PlatformException catch (e) {
      return VerificationOutcome.error(e.message ?? 'platform_error');
    }
  }
}
