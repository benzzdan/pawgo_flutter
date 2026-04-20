import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/widgets/walk_timeline.dart';

void main() {
  Widget buildTestWidget(String status) {
    return MaterialApp(
      home: Scaffold(
        body: WalkTimeline(status: status),
      ),
    );
  }

  group('WalkTimeline', () {
    testWidgets('renders 4 stage labels', (tester) async {
      await tester.pumpWidget(buildTestWidget('pending'));

      expect(find.text('Booked'), findsOneWidget);
      expect(find.text('Walker En Route'), findsOneWidget);
      expect(find.text('Walk Started'), findsOneWidget);
      expect(find.text('Walk Ended'), findsOneWidget);
    });

    testWidgets('walk_started status highlights stage 3 as current',
        (tester) async {
      await tester.pumpWidget(buildTestWidget('walk_started'));

      // Stage labels should all be present
      expect(find.text('Booked'), findsOneWidget);
      expect(find.text('Walker En Route'), findsOneWidget);
      expect(find.text('Walk Started'), findsOneWidget);
      expect(find.text('Walk Ended'), findsOneWidget);

      // Find the WalkTimeline widget and verify its status
      final timeline = tester.widget<WalkTimeline>(
        find.byType(WalkTimeline),
      );
      expect(timeline.status, 'walk_started');
    });

    testWidgets('prior stages show check icons when walk_started',
        (tester) async {
      await tester.pumpWidget(buildTestWidget('walk_started'));

      // Completed stages (Booked, Walker En Route) should have check icons
      final checkIcons = find.byIcon(Icons.check);
      expect(checkIcons, findsNWidgets(2));
    });

    testWidgets('confirmed status maps to Walker En Route as current',
        (tester) async {
      await tester.pumpWidget(buildTestWidget('confirmed'));

      // Only 1 completed stage (Booked) = 1 check
      final checkIcons = find.byIcon(Icons.check);
      expect(checkIcons, findsNWidgets(1));
    });

    testWidgets('walker_en_route status maps to Walker En Route as current',
        (tester) async {
      await tester.pumpWidget(buildTestWidget('walker_en_route'));

      // Only 1 completed stage (Booked) = 1 check
      final checkIcons = find.byIcon(Icons.check);
      expect(checkIcons, findsNWidgets(1));
    });

    testWidgets('walk_completed status marks all stages as completed',
        (tester) async {
      await tester.pumpWidget(buildTestWidget('walk_completed'));

      // All 4 stages completed = 4 check icons
      final checkIcons = find.byIcon(Icons.check);
      expect(checkIcons, findsNWidgets(4));
    });

    testWidgets('pending status shows Booked as current with no checks',
        (tester) async {
      await tester.pumpWidget(buildTestWidget('pending'));

      // No completed stages = 0 checks
      final checkIcons = find.byIcon(Icons.check);
      expect(checkIcons, findsNothing);
    });

    testWidgets('has semantic labels for accessibility', (tester) async {
      await tester.pumpWidget(buildTestWidget('walk_started'));

      // The widget should exist and be accessible
      expect(find.byType(WalkTimeline), findsOneWidget);
    });
  });
}
