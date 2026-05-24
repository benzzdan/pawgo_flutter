/// Environment configuration for Supabase and third-party services.
///
/// Values are sourced from `--dart-define` at build/run time, with sensible
/// defaults so `flutter run` works out of the box for local development.
///
/// Override at runtime, e.g.:
///   flutter run \
///     --dart-define=SUPABASE_URL=http://192.168.1.42:8000 \
///     --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// Or use scripts/dev-run.sh which auto-detects the Mac's LAN IP.
class Env {
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String revenueCatApiKey;
  final String posthogApiKey;
  final String posthogHost;
  final String mapboxAccessToken;

  const Env._({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.revenueCatApiKey,
    required this.posthogApiKey,
    required this.posthogHost,
    required this.mapboxAccessToken,
  });

  // ---- Local dev defaults (used when no --dart-define is supplied) ----

  static const _localSupabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://192.168.0.146:8000',
  );
  static const _localSupabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
  );
  static const _revenueCatApiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue: 'appl_LOCAL_DEV_KEY',
  );
  static const _posthogApiKey = String.fromEnvironment(
    'POSTHOG_API_KEY',
    defaultValue: 'phc_LOCAL_DEV_KEY',
  );
  static const _posthogHost = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://us.i.posthog.com',
  );
  static const _mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: 'YOUR_MAPBOX_ACCESS_TOKEN',
  );

  /// Local Docker Compose Supabase stack.
  static const local = Env._(
    supabaseUrl: _localSupabaseUrl,
    supabaseAnonKey: _localSupabaseAnonKey,
    revenueCatApiKey: _revenueCatApiKey,
    posthogApiKey: _posthogApiKey,
    posthogHost: _posthogHost,
    mapboxAccessToken: _mapboxAccessToken,
  );

  /// Production Supabase project (update before deploying).
  static const production = Env._(
    supabaseUrl: 'https://YOUR_PROJECT_REF.supabase.co',
    supabaseAnonKey: 'YOUR_PRODUCTION_ANON_KEY',
    revenueCatApiKey: 'YOUR_REVENUECAT_API_KEY',
    posthogApiKey: 'YOUR_POSTHOG_API_KEY',
    posthogHost: 'https://us.i.posthog.com',
    mapboxAccessToken: 'YOUR_MAPBOX_ACCESS_TOKEN',
  );

  /// Active environment — change this to switch targets.
  static const current = local;
}
