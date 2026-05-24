import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/utils/media_url_rewriter.dart';

void main() {
  group('rewriteMediaUrl', () {
    const target = 'http://192.168.0.146:8000';

    test('replaces stale host with target host', () {
      const url = 'http://10.223.6.26:8000/storage/v1/object/public/walk-media/abc.jpg?apikey=K';
      expect(
        rewriteMediaUrl(url, supabaseUrl: target),
        'http://192.168.0.146:8000/storage/v1/object/public/walk-media/abc.jpg?apikey=K',
      );
    });

    test('replaces localhost variants', () {
      const url = 'http://localhost:8000/storage/v1/object/public/walk-media/x.jpg';
      expect(rewriteMediaUrl(url, supabaseUrl: target),
          'http://192.168.0.146:8000/storage/v1/object/public/walk-media/x.jpg');
    });

    test('leaves already-correct host untouched', () {
      const url = 'http://192.168.0.146:8000/storage/v1/object/public/walk-media/x.jpg';
      expect(rewriteMediaUrl(url, supabaseUrl: target), url);
    });

    test('returns null for null input', () {
      expect(rewriteMediaUrl(null, supabaseUrl: target), null);
    });

    test('returns input unchanged when not a storage URL (defensive)', () {
      const url = 'https://example.com/photo.jpg';
      expect(rewriteMediaUrl(url, supabaseUrl: target), url);
    });

    test('respects https target', () {
      const url = 'http://10.223.6.26:8000/storage/v1/object/public/walk-media/x.jpg';
      expect(rewriteMediaUrl(url, supabaseUrl: 'https://api.pawgo.app'),
          'https://api.pawgo.app/storage/v1/object/public/walk-media/x.jpg');
    });

    test('URL with no query param: no spurious "?" is introduced', () {
      const url = 'http://10.223.6.26:8000/storage/v1/object/public/walk-media/x.jpg';
      final out = rewriteMediaUrl(url, supabaseUrl: target);
      expect(out, 'http://192.168.0.146:8000/storage/v1/object/public/walk-media/x.jpg');
      expect(out, isNot(contains('?')));
    });

    test('URL with fragment preserves the fragment after host rewrite', () {
      const url = 'http://10.223.6.26:8000/storage/v1/object/public/walk-media/x.jpg#anchor';
      expect(
        rewriteMediaUrl(url, supabaseUrl: target),
        'http://192.168.0.146:8000/storage/v1/object/public/walk-media/x.jpg#anchor',
      );
    });

    test('garbage supabaseUrl never throws and falls back to input', () {
      // `Uri.tryParse` returns null for inputs with spaces / invalid syntax,
      // so the rewriter should bail and return the original URL.
      const url = 'http://10.223.6.26:8000/storage/v1/object/public/walk-media/x.jpg';
      expect(
        () => rewriteMediaUrl(url, supabaseUrl: 'not a uri ::::'),
        returnsNormally,
      );
      expect(rewriteMediaUrl(url, supabaseUrl: 'not a uri ::::'), url);
    });

    test('empty supabaseUrl never throws', () {
      // Empty string parses to an empty URI (no scheme/host), so the
      // rewriter can't produce a usable absolute URL. We don't require a
      // specific shape here — only that it doesn't crash. This pins
      // observed behavior so a future hardening change has to update it.
      const url = 'http://10.223.6.26:8000/storage/v1/object/public/walk-media/x.jpg';
      expect(
        () => rewriteMediaUrl(url, supabaseUrl: ''),
        returnsNormally,
      );
    });

    test('https target with no port does not glue :443 onto the result', () {
      const url = 'http://10.223.6.26:8000/storage/v1/object/public/walk-media/x.jpg';
      final out = rewriteMediaUrl(url, supabaseUrl: 'https://api.pawgo.app');
      expect(out, 'https://api.pawgo.app/storage/v1/object/public/walk-media/x.jpg');
      expect(out, isNot(contains(':443')));
    });
  });
}
