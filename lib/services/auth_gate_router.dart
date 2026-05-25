import 'package:supabase_flutter/supabase_flutter.dart';

/// Where the _AuthGate should send a freshly-signed-in user.
///
/// The decision is based on `users.onboarding_completed_at`:
/// - `IS NULL`  → `/welcome` (run the new welcome → role → permissions flow)
/// - non-null   → `/home`    (returning user, skip onboarding)
///
/// Extracted from `_AuthGate` so it's unit-testable against a mocked
/// SupabaseClient without spinning up the auth state stream.
class AuthGateRouter {
  AuthGateRouter({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  /// Returns `/home` or `/welcome` based on the user's row.
  ///
  /// Defensive: any error reading the row falls back to `/welcome`, since
  /// showing the onboarding once-more is far less harmful than dropping
  /// the user onto `/home` and missing a required setup step.
  Future<String> destinationFor(String userId) async {
    try {
      final row = await _supabase
          .from('users')
          .select('onboarding_completed_at')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return '/welcome';
      final completedAt = row['onboarding_completed_at'];
      return completedAt == null ? '/welcome' : '/home';
    } catch (_) {
      return '/welcome';
    }
  }
}
