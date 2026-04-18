import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/widgets/walk_timeline.dart';

// ---------------------------------------------------------------------------
// Tests for US-014 & US-015: Walk timeline component
//
// Pure Dart tests for stage mapping logic, plus widget tests for the
// full-screen (vertical) and compact (horizontal) timeline variants.
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // ── Pure Dart: Stage mapping logic ──

  group('WalkTimelineStage.fromBookingStatus', () {
    test('pending maps to Booked stage', () {
      expect(
        WalkTimelineStage.fromBookingStatus('pending'),
        WalkTimelineStage.booked,
      );
    });

    test('confirmed maps to Booked stage', () {
      expect(
        WalkTimelineStage.fromBookingStatus('confirmed'),
        WalkTimelineStage.booked,
      );
    });

    test('walker_en_route maps to Walker En Route stage', () {
      expect(
        WalkTimelineStage.fromBookingStatus('walker_en_route'),
        WalkTimelineStage.walkerEnRoute,
      );
    });

    test('walk_started maps to Walk Started stage', () {
      expect(
        WalkTimelineStage.fromBookingStatus('walk_started'),
        WalkTimelineStage.walkStarted,
      );
    });

    test('walk_completed maps to Walk Ended stage', () {
      expect(
        WalkTimelineStage.fromBookingStatus('walk_completed'),
        WalkTimelineStage.walkEnded,
      );
    });

    test('unknown status defaults to Booked stage', () {
      expect(
        WalkTimelineStage.fromBookingStatus('cancelled_by_owner'),
        WalkTimelineStage.booked,
      );
      expect(
        WalkTimelineStage.fromBookingStatus('rejected_by_walker'),
        WalkTimelineStage.booked,
      );
    });
  });

  group('WalkTimelineStage state helpers', () {
    test('stages before current are completed', () {
      final current = WalkTimelineStage.walkStarted;
      expect(WalkTimelineStage.booked.isCompleted(current), isTrue);
      expect(WalkTimelineStage.walkerEnRoute.isCompleted(current), isTrue);
      expect(WalkTimelineStage.walkStarted.isCompleted(current), isFalse);
      expect(WalkTimelineStage.walkEnded.isCompleted(current), isFalse);
    });

    test('current stage is identified correctly', () {
      final current = WalkTimelineStage.walkerEnRoute;
      expect(WalkTimelineStage.booked.isCurrent(current), isFalse);
      expect(WalkTimelineStage.walkerEnRoute.isCurrent(current), isTrue);
      expect(WalkTimelineStage.walkStarted.isCurrent(current), isFalse);
    });

    test('stages after current are future', () {
      final current = WalkTimelineStage.walkerEnRoute;
      expect(WalkTimelineStage.booked.isFuture(current), isFalse);
      expect(WalkTimelineStage.walkerEnRoute.isFuture(current), isFalse);
      expect(WalkTimelineStage.walkStarted.isFuture(current), isTrue);
      expect(WalkTimelineStage.walkEnded.isFuture(current), isTrue);
    });
  });

  // ── US-014: Full-screen vertical timeline widget ──

  group('US-014: WalkTimeline (vertical, full-screen)', () {
    testWidgets('renders all 4 stage labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: const Scaffold(
            body: WalkTimeline(
              currentStatus: 'walk_started',
              layout: WalkTimelineLayout.vertical,
            ),
          ),
        ),
      );

      expect(find.text('Booked'), findsOneWidget);
      expect(find.text('Walker En Route'), findsOneWidget);
      expect(find.text('Walk Started'), findsOneWidget);
      expect(find.text('Walk Ended'), findsOneWidget);
    });

    testWidgets('current stage is highlighted with brand color',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: const Scaffold(
            body: WalkTimeline(
              currentStatus: 'walker_en_route',
              layout: WalkTimelineLayout.vertical,
            ),
          ),
        ),
      );

      // The current stage node should use the brand color (goldenPaw)
      final currentStageNode = find.byKey(
        const ValueKey('timeline_node_walkerEnRoute'),
      );
      expect(currentStageNode, findsOneWidget);

      final container = tester.widget<Container>(
        find.descendant(
          of: currentStageNode,
          matching: find.byKey(
            const ValueKey('timeline_dot_walkerEnRoute'),
          ),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.goldenPaw);
    });

    testWidgets('completed stages show a checkmark icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: const Scaffold(
            body: WalkTimeline(
              currentStatus: 'walk_started',
              layout: WalkTimelineLayout.vertical,
            ),
          ),
        ),
      );

      // Booked and Walker En Route are completed — each should have a check icon
      final checkIcons = find.byIcon(Icons.check);
      expect(checkIcons, findsNWidgets(2));
    });

    testWidgets('future stages are shown in neutral/inactive style',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: const Scaffold(
            body: WalkTimeline(
              currentStatus: 'walker_en_route',
              layout: WalkTimelineLayout.vertical,
            ),
          ),
        ),
      );

      // Walk Started and Walk Ended are future
      final futureNode = find.byKey(
        const ValueKey('timeline_dot_walkStarted'),
      );
      expect(futureNode, findsOneWidget);
      final container = tester.widget<Container>(futureNode);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.gray300);
    });

    testWidgets('walk_completed status shows all stages as completed except Walk Ended which is current',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: const Scaffold(
            body: WalkTimeline(
              currentStatus: 'walk_completed',
              layout: WalkTimelineLayout.vertical,
            ),
          ),
        ),
      );

      // 3 completed stages (Booked, Walker En Route, Walk Started) → 3 checks
      final checkIcons = find.byIcon(Icons.check);
      expect(checkIcons, findsNWidgets(3));
    });
  });

  // ── US-015: Compact horizontal timeline widget ──

  group('US-015: WalkTimeline (horizontal, compact)', () {
    testWidgets('renders all 4 stage labels in compact layout',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: const Scaffold(
            body: WalkTimeline(
              currentStatus: 'walk_started',
              layout: WalkTimelineLayout.horizontal,
            ),
          ),
        ),
      );

      expect(find.text('Booked'), findsOneWidget);
      expect(find.text('En Route'), findsOneWidget);
      expect(find.text('Walking'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('completed stages show check in compact layout',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: const Scaffold(
            body: WalkTimeline(
              currentStatus: 'walk_started',
              layout: WalkTimelineLayout.horizontal,
            ),
          ),
        ),
      );

      final checkIcons = find.byIcon(Icons.check);
      expect(checkIcons, findsNWidgets(2));
    });
  });

  // ── US-015: Home screen Active Walk card with timeline ──

  group('US-015: ActiveWalkTimelineCard', () {
    testWidgets('renders timeline and map/chat buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: Scaffold(
            body: ActiveWalkTimelineCard(
              bookingId: 'test-booking-123',
              bookingStatus: 'walk_started',
              walkerName: 'Carlos',
              dogName: 'Buddy',
              onTap: () {},
              onMapTap: () {},
              onChatTap: () {},
            ),
          ),
        ),
      );

      // Timeline stages should be present (compact labels)
      expect(find.text('Booked'), findsOneWidget);
      expect(find.text('En Route'), findsOneWidget);
      expect(find.text('Walking'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // Map and Chat icon buttons should be present
      expect(find.byKey(const ValueKey('active_walk_card_map_btn')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('active_walk_card_chat_btn')),
          findsOneWidget);
    });

    testWidgets('tapping card triggers onTap callback', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: Scaffold(
            body: ActiveWalkTimelineCard(
              bookingId: 'test-booking-123',
              bookingStatus: 'walk_started',
              walkerName: 'Carlos',
              dogName: 'Buddy',
              onTap: () => tapped = true,
              onMapTap: () {},
              onChatTap: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ActiveWalkTimelineCard));
      expect(tapped, isTrue);
    });

    testWidgets('tapping map button triggers onMapTap', (tester) async {
      bool mapTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: Scaffold(
            body: ActiveWalkTimelineCard(
              bookingId: 'test-booking-123',
              bookingStatus: 'walker_en_route',
              walkerName: 'Carlos',
              dogName: 'Buddy',
              onTap: () {},
              onMapTap: () => mapTapped = true,
              onChatTap: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('active_walk_card_map_btn')));
      expect(mapTapped, isTrue);
    });

    testWidgets('tapping chat button triggers onChatTap', (tester) async {
      bool chatTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: Scaffold(
            body: ActiveWalkTimelineCard(
              bookingId: 'test-booking-123',
              bookingStatus: 'walk_started',
              walkerName: 'Carlos',
              dogName: 'Buddy',
              onTap: () {},
              onMapTap: () {},
              onChatTap: () => chatTapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('active_walk_card_chat_btn')));
      expect(chatTapped, isTrue);
    });

    testWidgets('displays walker name and dog name', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: Scaffold(
            body: ActiveWalkTimelineCard(
              bookingId: 'test-booking-123',
              bookingStatus: 'walk_started',
              walkerName: 'Maria',
              dogName: 'Rex',
              onTap: () {},
              onMapTap: () {},
              onChatTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Maria'), findsOneWidget);
      expect(find.textContaining('Rex'), findsOneWidget);
    });
  });
}
