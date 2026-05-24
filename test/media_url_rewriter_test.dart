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
  });
}
