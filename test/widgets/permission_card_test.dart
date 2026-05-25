import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pawgo/widgets/permission_card.dart';

void main() {
  group('PermissionCard', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      required PermissionCardStatus status,
      VoidCallback? onAllow,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PermissionCard(
              icon: Icons.location_on,
              title: 'Location',
              body: 'We use your location to match you with nearby walkers.',
              status: status,
              onAllow: onAllow ?? () {},
              allowLabel: 'Allow location',
            ),
          ),
        ),
      );
    }

    testWidgets('renders title, body, and Allow CTA', (tester) async {
      await pumpCard(tester, status: PermissionCardStatus.notYet);

      expect(find.text('Location'), findsOneWidget);
      expect(find.textContaining('We use your location'), findsOneWidget);
      expect(find.text('Allow location'), findsOneWidget);
    });

    testWidgets('not-yet status shows the Not yet pill', (tester) async {
      await pumpCard(tester, status: PermissionCardStatus.notYet);

      final pill = tester.widget<Container>(
        find.byKey(const Key('permissionCardPill_notYet')),
      );
      final decoration = pill.decoration as BoxDecoration;
      // Neutral grey background for "not yet".
      expect(decoration.color, isNot(equals(Colors.green)));
      expect(decoration.color, isNot(equals(Colors.red)));
    });

    testWidgets('granted status shows a green-ish pill', (tester) async {
      await pumpCard(tester, status: PermissionCardStatus.granted);

      final pill = tester.widget<Container>(
        find.byKey(const Key('permissionCardPill_granted')),
      );
      final decoration = pill.decoration as BoxDecoration;
      // Must clearly differ from the notYet pill color.
      expect(decoration.color, isNotNull);
      // Sanity check: a green family (Hue around 100°-160° on HSV).
      final color = decoration.color!;
      final hsv = HSVColor.fromColor(color);
      expect(hsv.hue, inInclusiveRange(80, 170),
          reason: 'granted pill should look green');
    });

    testWidgets('denied status shows a red-ish pill', (tester) async {
      await pumpCard(tester, status: PermissionCardStatus.denied);

      final pill = tester.widget<Container>(
        find.byKey(const Key('permissionCardPill_denied')),
      );
      final decoration = pill.decoration as BoxDecoration;
      expect(decoration.color, isNotNull);
      final color = decoration.color!;
      final hsv = HSVColor.fromColor(color);
      // Red family wraps around 0/360 — accept either end.
      final hue = hsv.hue;
      final isRedish = hue <= 25 || hue >= 335;
      expect(isRedish, isTrue, reason: 'denied pill should look red');
    });

    testWidgets('Allow CTA fires onAllow', (tester) async {
      int taps = 0;
      await pumpCard(
        tester,
        status: PermissionCardStatus.notYet,
        onAllow: () => taps++,
      );

      await tester.tap(find.text('Allow location'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('Allow CTA is hidden once status is granted', (tester) async {
      await pumpCard(tester, status: PermissionCardStatus.granted);

      // The button shouldn't render when permission is already granted.
      expect(find.text('Allow location'), findsNothing);
    });
  });
}
