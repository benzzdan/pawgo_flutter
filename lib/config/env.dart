/// Environment configuration for Supabase connectivity.
///
/// Switch between [local] and [production] profiles
/// by changing the active config in main.dart.
class Env {
  final String supabaseUrl;
  final String supabaseAnonKey;

  const Env._({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  /// Local Docker Compose Supabase stack.
  static const local = Env._(
    supabaseUrl: 'http://localhost:8000',
    supabaseAnonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
  );

  /// Production Supabase project (update before deploying).
  static const production = Env._(
    supabaseUrl: 'https://YOUR_PROJECT_REF.supabase.co',
    supabaseAnonKey: 'YOUR_PRODUCTION_ANON_KEY',
  );
}
