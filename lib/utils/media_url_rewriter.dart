/// Rewrites the host of a `walk-media` storage URL to match the configured
/// Supabase URL. Fixes URLs baked at upload time when the backend's
/// `API_EXTERNAL_URL` pointed at a stale LAN IP.
///
/// Returns null if [url] is null. Returns [url] unchanged if it does not
/// look like a Supabase storage URL.
String? rewriteMediaUrl(String? url, {required String supabaseUrl}) {
  if (url == null) return null;
  if (!url.contains('/storage/v1/object/')) return url;
  final source = Uri.tryParse(url);
  final target = Uri.tryParse(supabaseUrl);
  if (source == null || target == null) return url;
  // Build a fresh URI so an https target with default port (e.g.
  // https://api.pawgo.app) cleanly drops the source's :8000. `Uri.replace`
  // keeps the existing port when `port` is null, so we cannot use it here.
  return Uri(
    scheme: target.scheme,
    host: target.host,
    port: target.hasPort ? target.port : null,
    path: source.path,
    query: source.query.isEmpty ? null : source.query,
    fragment: source.fragment.isEmpty ? null : source.fragment,
  ).toString();
}
