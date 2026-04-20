import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/widgets/walk_photos_tab.dart';
import 'package:pawgo/widgets/paw_progress_indicator.dart';

void main() {
  group('WalkPhotosTab', () {
    testWidgets('shows PawProgressIndicator when loading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WalkPhotosTab(
              isLoading: true,
              photos: [],
              isWalker: false,
            ),
          ),
        ),
      );

      expect(find.byType(PawProgressIndicator), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('shows empty state with message when no photos and not loading',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WalkPhotosTab(
              isLoading: false,
              photos: [],
              isWalker: false,
            ),
          ),
        ),
      );

      expect(find.byType(PawProgressIndicator), findsNothing);
      expect(find.text('No photos yet'), findsOneWidget);
    });

    testWidgets('shows photo grid when photos are loaded', (tester) async {
      final photos = [
        {
          'id': '1',
          'media_url': 'https://example.com/photo1.jpg',
          'media_type': 'image',
          'created_at': '2026-04-19T12:00:00Z',
          'sender_id': 'user-1',
        },
        {
          'id': '2',
          'media_url': 'https://example.com/photo2.jpg',
          'media_type': 'image',
          'created_at': '2026-04-19T12:01:00Z',
          'sender_id': 'user-1',
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WalkPhotosTab(
                isLoading: false,
                photos: photos,
                isWalker: false,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(PawProgressIndicator), findsNothing);
      expect(find.text('No photos yet'), findsNothing);
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('walker sees Take Photo button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WalkPhotosTab(
              isLoading: false,
              photos: [],
              isWalker: true,
            ),
          ),
        ),
      );

      expect(find.text('Take Photo'), findsOneWidget);
    });

    testWidgets('owner does not see Take Photo button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WalkPhotosTab(
              isLoading: false,
              photos: [],
              isWalker: false,
            ),
          ),
        ),
      );

      expect(find.text('Take Photo'), findsNothing);
    });

    testWidgets('shows uploading indicator when isUploading is true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WalkPhotosTab(
              isLoading: false,
              photos: [],
              isWalker: true,
              isUploading: true,
            ),
          ),
        ),
      );

      // The take photo button area should show a loader instead of the text
      // when uploading
      final pawLoaders = find.byType(PawProgressIndicator);
      expect(pawLoaders, findsOneWidget);
    });
  });
}
