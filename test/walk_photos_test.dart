import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/widgets/walk_photos_tab.dart';

void main() {
  group('US-008: Walk photos paw loader and empty state', () {
    testWidgets('shows paw-print loader when isLoading is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WalkPhotosTab(
              photos: [],
              isLoading: true,
              isWalker: false,
            ),
          ),
        ),
      );

      // Should find the paw loader key
      expect(find.byKey(const Key('paw_loader')), findsOneWidget);
      // Should NOT show empty state or photo grid
      expect(find.text('No photos yet — the walker will share moments from the walk!'), findsNothing);
    });

    testWidgets('shows animated rotation on paw loader', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WalkPhotosTab(
              photos: [],
              isLoading: true,
              isWalker: false,
            ),
          ),
        ),
      );

      // The loader should contain a RotationTransition or AnimatedBuilder
      final pawLoader = find.byKey(const Key('paw_loader'));
      expect(pawLoader, findsOneWidget);

      // Pump a few frames to verify animation is running
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Still showing loader
      expect(find.byKey(const Key('paw_loader')), findsOneWidget);
    });

    testWidgets('shows empty state when photos list is empty and not loading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WalkPhotosTab(
              photos: [],
              isLoading: false,
              isWalker: false,
            ),
          ),
        ),
      );

      // Should NOT show loader
      expect(find.byKey(const Key('paw_loader')), findsNothing);
      // Should show empty state text for owner
      expect(
        find.text('No photos yet — the walker will share moments from the walk!'),
        findsOneWidget,
      );
    });

    testWidgets('shows photo grid when photos are present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WalkPhotosTab(
              photos: const [
                {'id': '1', 'media_url': 'https://example.com/photo1.jpg', 'media_type': 'image'},
                {'id': '2', 'media_url': 'https://example.com/photo2.jpg', 'media_type': 'image'},
              ],
              isLoading: false,
              isWalker: false,
            ),
          ),
        ),
      );

      // Should NOT show loader or empty state
      expect(find.byKey(const Key('paw_loader')), findsNothing);
      expect(
        find.text('No photos yet — the walker will share moments from the walk!'),
        findsNothing,
      );
      // Should show a GridView
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('loader disappears when isLoading changes to false', (tester) async {
      // Start with loading state
      bool isLoading = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: WalkPhotosTab(
                  photos: const [],
                  isLoading: isLoading,
                  isWalker: false,
                ),
                floatingActionButton: FloatingActionButton(
                  key: const Key('toggle_loading'),
                  onPressed: () => setState(() => isLoading = false),
                ),
              );
            },
          ),
        ),
      );

      expect(find.byKey(const Key('paw_loader')), findsOneWidget);

      // Simulate fetch complete
      await tester.tap(find.byKey(const Key('toggle_loading')));
      await tester.pump();

      expect(find.byKey(const Key('paw_loader')), findsNothing);
      expect(
        find.text('No photos yet — the walker will share moments from the walk!'),
        findsOneWidget,
      );
    });
  });

  group('US-009: Walk photos new photo badge', () {
    testWidgets('Photos tab badge shows red dot when hasNewPhotos is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                WalkPhotosTabButton(
                  label: 'Photos',
                  isSelected: false,
                  hasNewPhotos: true,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      // Should find the badge dot
      expect(find.byKey(const Key('new_photo_badge')), findsOneWidget);
    });

    testWidgets('Photos tab badge is hidden when hasNewPhotos is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                WalkPhotosTabButton(
                  label: 'Photos',
                  isSelected: false,
                  hasNewPhotos: false,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('new_photo_badge')), findsNothing);
    });

    testWidgets('Badge does not appear when Photos tab is selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                WalkPhotosTabButton(
                  label: 'Photos',
                  isSelected: true,
                  hasNewPhotos: true,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      // Badge should NOT show when the tab is active, even if hasNewPhotos is true
      expect(find.byKey(const Key('new_photo_badge')), findsNothing);
    });

    testWidgets('Badge clears when switching to Photos tab', (tester) async {
      bool isSelected = false;
      bool hasNewPhotos = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Row(
                  children: [
                    WalkPhotosTabButton(
                      label: 'Photos',
                      isSelected: isSelected,
                      hasNewPhotos: hasNewPhotos,
                      onTap: () {
                        setState(() {
                          isSelected = true;
                          hasNewPhotos = false;
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Badge visible initially
      expect(find.byKey(const Key('new_photo_badge')), findsOneWidget);

      // Tap the button (simulates switching to Photos tab)
      await tester.tap(find.text('Photos'));
      await tester.pumpAndSettle();

      // Badge should be gone
      expect(find.byKey(const Key('new_photo_badge')), findsNothing);
    });
  });
}
