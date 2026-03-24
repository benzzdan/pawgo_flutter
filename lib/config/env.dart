/// Environment configuration for Supabase connectivity.
///
/// Switch between [Env.local] and [Env.production] as needed.
class Env {
  final String supabaseUrl;
  final String supabaseAnonKey;

  const Env._({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  /// Local Supabase instance (Docker).
  static const local = Env._(
    supabaseUrl: 'http://localhost:54321',
    supabaseAnonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
  );

  /// Production Supabase instance — replace with real values.
  static const production = Env._(
    supabaseUrl: 'https://your-project.supabase.co',
    supabaseAnonKey: 'your-production-anon-key',
  );

  /// Active environment — change this to switch targets.
  static const current = local;
}
