import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/utils/home_widget_bridge.dart';

void main() {
  group('HomeWidgetBridge', () {
    late List<Map<String, dynamic>> savedData;
    late int updateCallCount;
    late HomeWidgetBridge bridge;

    setUp(() {
      savedData = [];
      updateCallCount = 0;

      bridge = HomeWidgetBridge(
        saveWidgetData: (String key, dynamic value) async {
          savedData.add({'key': key, 'value': value});
        },
        updateWidget: () async {
          updateCallCount++;
        },
      );
    });

    test('saves walker name, stage, and elapsed time on status change',
        () async {
      await bridge.onBookingStatusChanged(
        newStatus: 'walk_started',
        walkerName: 'Maria',
        dogName: 'Rex',
        elapsedMinutes: 5,
      );

      final keys = savedData.map((d) => d['key']).toList();
      expect(keys, contains('walkerName'));
      expect(keys, contains('stage'));
      expect(keys, contains('elapsedMinutes'));

      final walkerEntry =
          savedData.firstWhere((d) => d['key'] == 'walkerName');
      expect(walkerEntry['value'], 'Maria');

      final stageEntry = savedData.firstWhere((d) => d['key'] == 'stage');
      expect(stageEntry['value'], 'Walk in progress');

      final elapsedEntry =
          savedData.firstWhere((d) => d['key'] == 'elapsedMinutes');
      expect(elapsedEntry['value'], 5);
    });

    test('calls updateWidget after saving data', () async {
      await bridge.onBookingStatusChanged(
        newStatus: 'walk_started',
        walkerName: 'Maria',
        dogName: 'Rex',
        elapsedMinutes: 0,
      );

      expect(updateCallCount, 1);
    });

    test('shows no active walk for completion status', () async {
      await bridge.onBookingStatusChanged(
        newStatus: 'walk_completed',
        walkerName: 'Maria',
        dogName: 'Rex',
        elapsedMinutes: 30,
      );

      final stageEntry = savedData.firstWhere((d) => d['key'] == 'stage');
      expect(stageEntry['value'], 'No active walk');
      expect(updateCallCount, 1);
    });

    test('shows no active walk for cancellation statuses', () async {
      final cancellationStatuses = [
        'cancelled',
        'cancelled_by_owner',
        'cancelled_by_walker',
        'rejected_by_walker',
      ];

      for (final status in cancellationStatuses) {
        savedData.clear();
        updateCallCount = 0;

        await bridge.onBookingStatusChanged(
          newStatus: status,
          walkerName: 'Maria',
          dogName: 'Rex',
          elapsedMinutes: 0,
        );

        final stageEntry = savedData.firstWhere((d) => d['key'] == 'stage');
        expect(stageEntry['value'], 'No active walk',
            reason: 'should show no active walk for $status');
      }
    });

    test('updates elapsed time independently', () async {
      await bridge.updateElapsedTime(elapsedMinutes: 15);

      final elapsedEntry =
          savedData.firstWhere((d) => d['key'] == 'elapsedMinutes');
      expect(elapsedEntry['value'], 15);
      expect(updateCallCount, 1);
    });

    test('formats stage labels for display', () {
      expect(HomeWidgetBridge.stageLabel('walker_en_route'), 'Walker en route');
      expect(HomeWidgetBridge.stageLabel('walk_started'), 'Walk in progress');
      expect(HomeWidgetBridge.stageLabel('walk_completed'), 'No active walk');
      expect(HomeWidgetBridge.stageLabel('cancelled'), 'No active walk');
    });
  });
}
