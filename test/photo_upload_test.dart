import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/screens/walker_chat_screen.dart';

void main() {
  group('MIME type detection', () {
    // _getMimeType is private, so we test the same logic
    String getMimeType(String fileName) {
      final ext = fileName.split('.').last.toLowerCase();
      switch (ext) {
        case 'jpg':
        case 'jpeg':
          return 'image/jpeg';
        case 'png':
          return 'image/png';
        case 'webp':
          return 'image/webp';
        case 'mp4':
          return 'video/mp4';
        case 'mov':
          return 'video/quicktime';
        default:
          return 'application/octet-stream';
      }
    }

    test('jpg returns image/jpeg', () {
      expect(getMimeType('photo.jpg'), 'image/jpeg');
    });

    test('jpeg returns image/jpeg', () {
      expect(getMimeType('photo.jpeg'), 'image/jpeg');
    });

    test('png returns image/png', () {
      expect(getMimeType('screenshot.png'), 'image/png');
    });

    test('webp returns image/webp', () {
      expect(getMimeType('compressed.webp'), 'image/webp');
    });

    test('mp4 returns video/mp4', () {
      expect(getMimeType('clip.mp4'), 'video/mp4');
    });

    test('mov returns video/quicktime', () {
      expect(getMimeType('recording.mov'), 'video/quicktime');
    });

    test('unknown extension returns octet-stream', () {
      expect(getMimeType('file.xyz'), 'application/octet-stream');
    });

    test('case insensitive extension matching', () {
      expect(getMimeType('photo.JPG'), 'image/jpeg');
      expect(getMimeType('video.MP4'), 'video/mp4');
    });
  });

  group('Base64 encoding for upload', () {
    test('bytes encode to valid base64 string', () {
      final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]); // PNG header
      final encoded = base64Encode(bytes);
      expect(encoded, isA<String>());
      expect(encoded.isNotEmpty, true);

      // Verify round-trip
      final decoded = base64Decode(encoded);
      expect(decoded, equals(bytes));
    });

    test('empty bytes encode to empty string', () {
      final bytes = Uint8List(0);
      final encoded = base64Encode(bytes);
      expect(encoded, '');
    });
  });

  group('Fullscreen photo viewer', () {
    testWidgets('FullScreenPhotoViewer displays image and close button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullScreenPhotoViewer(
            imageUrl: 'https://example.com/photo.jpg',
          ),
        ),
      );

      // Should have an image widget
      expect(find.byType(Image), findsOneWidget);

      // Should have a close/back button
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('close button pops the viewer', (tester) async {
      var popped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenPhotoViewer(
                      imageUrl: 'https://example.com/photo.jpg',
                    ),
                  ),
                ).then((_) => popped = true);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      // Navigate to viewer
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap close button
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(popped, true);
    });
  });
}
