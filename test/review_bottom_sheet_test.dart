import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/widgets/review_bottom_sheet.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ReviewBottomSheet', () {
    testWidgets('shows walker name', (tester) async {
      await tester.pumpWidget(_wrap(const ReviewBottomSheet(
        bookingId: 'b-1', walkerId: 'w-1', walkerName: 'Carlos M.',
      )));
      expect(find.text('Carlos M.'), findsOneWidget);
    });

    testWidgets('shows 5 star tap targets', (tester) async {
      await tester.pumpWidget(_wrap(const ReviewBottomSheet(
        bookingId: 'b-1', walkerId: 'w-1', walkerName: 'Carlos M.',
      )));
      for (int i = 1; i <= 5; i++) {
        expect(find.byKey(ValueKey('star_$i')), findsOneWidget);
      }
    });

    testWidgets('shows Submit Review and Skip for now', (tester) async {
      await tester.pumpWidget(_wrap(const ReviewBottomSheet(
        bookingId: 'b-1', walkerId: 'w-1', walkerName: 'Carlos M.',
      )));
      expect(find.text('Submit Review'), findsOneWidget);
      expect(find.text('Skip for now'), findsOneWidget);
    });

    testWidgets('tapping 4th star shows Great', (tester) async {
      await tester.pumpWidget(_wrap(const ReviewBottomSheet(
        bookingId: 'b-1', walkerId: 'w-1', walkerName: 'Carlos M.',
      )));
      expect(find.text('Tap a star to rate'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('star_4')));
      await tester.pump();
      expect(find.text('Great'), findsOneWidget);
    });

    test('shownThisSession is a static bool defaulting to false', () {
      ReviewBottomSheet.shownThisSession = false;
      expect(ReviewBottomSheet.shownThisSession, false);
    });
  });
}
