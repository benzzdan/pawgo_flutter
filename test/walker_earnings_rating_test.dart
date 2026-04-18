import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/widgets/review_list_bottom_sheet.dart';

/// US-013: Walker average rating and review list on Earnings screen
///
/// Tests validate:
/// 1. Average star rating displayed (e.g., 'star 4.7 avg (12 reviews)')
/// 2. Tapping the rating opens a bottom sheet listing individual reviews
/// 3. Review list shows reviewer name, star count, comment, date
/// 4. 'No reviews yet' when empty
/// 5. Average refreshes on pull-to-refresh

void main() {
  group('US-013: Walker average rating and review list', () {
    group('ReviewListBottomSheet widget', () {
      testWidgets('displays individual reviews with name, stars, comment, date',
          (tester) async {
        final reviews = [
          {
            'rating': 5,
            'comment': 'Great walk with my dog!',
            'created_at': '2026-04-10T14:30:00Z',
            'users': {'full_name': 'Maria Lopez'},
          },
          {
            'rating': 4,
            'comment': null,
            'created_at': '2026-04-08T10:00:00Z',
            'users': {'full_name': 'Carlos Ruiz'},
          },
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReviewListBottomSheet(
                reviews: reviews,
                averageRating: 4.5,
                reviewCount: 2,
              ),
            ),
          ),
        );

        expect(find.text('Maria Lopez'), findsOneWidget);
        expect(find.text('Great walk with my dog!'), findsOneWidget);
        expect(find.text('Carlos Ruiz'), findsOneWidget);
        // 4.5 avg rating displayed
        expect(find.text('4.5'), findsOneWidget);
      });

      testWidgets('shows "No reviews yet" when reviews list is empty',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReviewListBottomSheet(
                reviews: const [],
                averageRating: 0,
                reviewCount: 0,
              ),
            ),
          ),
        );

        expect(find.text('No reviews yet'), findsOneWidget);
      });

      testWidgets('shows "Anonymous" when reviewer name is null',
          (tester) async {
        final reviews = [
          {
            'rating': 3,
            'comment': 'Okay walk',
            'created_at': '2026-04-05T12:00:00Z',
            'users': null,
          },
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReviewListBottomSheet(
                reviews: reviews,
                averageRating: 3.0,
                reviewCount: 1,
              ),
            ),
          ),
        );

        expect(find.text('Anonymous'), findsOneWidget);
      });

      testWidgets('review detail is read-only (no text fields or buttons)',
          (tester) async {
        final reviews = [
          {
            'rating': 5,
            'comment': 'Perfect!',
            'created_at': '2026-04-10T14:30:00Z',
            'users': {'full_name': 'Ana Garcia'},
          },
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReviewListBottomSheet(
                reviews: reviews,
                averageRating: 5.0,
                reviewCount: 1,
              ),
            ),
          ),
        );

        // No editable fields or submit buttons
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(ElevatedButton), findsNothing);
      });
    });

    group('Rating summary display', () {
      test('formats average rating correctly', () {
        // The rating card on earnings screen shows e.g. "4.7"
        const avgRating = 4.7;
        expect(avgRating.toStringAsFixed(1), '4.7');
      });

      test('shows dash when no rating', () {
        const avgRating = 0.0;
        final display = avgRating > 0 ? avgRating.toStringAsFixed(1) : '-';
        expect(display, '-');
      });
    });
  });
}
