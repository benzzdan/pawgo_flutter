/// Environment configuration for Supabase connectivity.
///
/// Switch between [Env.local] and [Env.production] as needed.
class Env {
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String revenueCatApiKey;
  final String posthogApiKey;
  final String posthogHost;

  const Env._({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.revenueCatApiKey,
    required this.posthogApiKey,
    required this.posthogHost,
  });

  /// Local Docker Compose Supabase stack.
  static const local = Env._(
    supabaseUrl: 'http://localhost:8000',
    supabaseAnonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
    revenueCatApiKey: 'appl_LOCAL_DEV_KEY',
    posthogApiKey: 'phc_LOCAL_DEV_KEY',
    posthogHost: 'https://us.i.posthog.com',
  );

  /// Production Supabase project (update before deploying).
  static const production = Env._(
    supabaseUrl: 'https://YOUR_PROJECT_REF.supabase.co',
    supabaseAnonKey: 'YOUR_PRODUCTION_ANON_KEY',
    revenueCatApiKey: 'YOUR_REVENUECAT_API_KEY',
    posthogApiKey: 'YOUR_POSTHOG_API_KEY',
    posthogHost: 'https://us.i.posthog.com',
  );

  /// Active environment — change this to switch targets.
  static const current = local;
}
