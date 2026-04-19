import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/services/live_activity_service.dart';
import 'package:pawgo/utils/live_activity_bridge.dart';

void main() {
  group('LiveActivityBridge', () {
    late LiveActivityService service;
    late LiveActivityBridge bridge;

    setUp(() {
      service = LiveActivityService(platformOverride: true);
      bridge = LiveActivityBridge(
        service: service,
        isPlatformSupported: false, // simulate non-iOS
      );
    });

    test('does not call start when platform is not supported', () async {
      await bridge.onBookingStatusChanged(
        newStatus: 'walker_en_route',
        walkerName: 'Maria',
        dogName: 'Rex',
      );
      expect(service.isActive, isFalse);
      expect(bridge.isTimerActive, isFalse);
    });

    test('calls start when platform IS supported and status is walker_en_route',
        () async {
      final svc = LiveActivityService(platformOverride: true);
      final b = LiveActivityBridge(service: svc, isPlatformSupported: true);

      await b.onBookingStatusChanged(
        newStatus: 'walker_en_route',
        walkerName: 'Maria',
        dogName: 'Rex',
      );

      expect(svc.isActive, isTrue);
      b.dispose();
    });

    test('calls start when status is walk_started', () async {
      final svc = LiveActivityService(platformOverride: true);
      final b = LiveActivityBridge(service: svc, isPlatformSupported: true);

      await b.onBookingStatusChanged(
        newStatus: 'walk_started',
        walkerName: 'Maria',
        dogName: 'Rex',
      );

      expect(svc.isActive, isTrue);
      expect(b.isTimerActive, isTrue);
      b.dispose();
    });

    test('calls end when status is walk_completed', () async {
      final svc = LiveActivityService(platformOverride: true);
      final b = LiveActivityBridge(service: svc, isPlatformSupported: true);

      await b.onBookingStatusChanged(
        newStatus: 'walk_started',
        walkerName: 'Maria',
        dogName: 'Rex',
      );
      expect(svc.isActive, isTrue);

      await b.onBookingStatusChanged(
        newStatus: 'walk_completed',
        walkerName: 'Maria',
        dogName: 'Rex',
      );
      expect(svc.isActive, isFalse);
      expect(b.isTimerActive, isFalse);
      b.dispose();
    });

    test('calls end on cancellation statuses', () async {
      final cancellationStatuses = [
        'cancelled',
        'cancelled_by_owner',
        'cancelled_by_walker',
        'rejected_by_walker',
      ];

      for (final status in cancellationStatuses) {
        final svc = LiveActivityService(platformOverride: true);
        final b = LiveActivityBridge(service: svc, isPlatformSupported: true);

        await b.onBookingStatusChanged(
          newStatus: 'walk_started',
          walkerName: 'Maria',
          dogName: 'Rex',
        );
        expect(svc.isActive, isTrue, reason: 'should be active before $status');

        await b.onBookingStatusChanged(
          newStatus: status,
          walkerName: 'Maria',
          dogName: 'Rex',
        );
        expect(svc.isActive, isFalse,
            reason: 'should be ended after $status');
        b.dispose();
      }
    });

    test('skips silently on Android (isPlatformSupported=false)', () async {
      final svc = LiveActivityService(platformOverride: true);
      final androidBridge = LiveActivityBridge(
        service: svc,
        isPlatformSupported: false,
      );

      await androidBridge.onBookingStatusChanged(
        newStatus: 'walk_started',
        walkerName: 'Maria',
        dogName: 'Rex',
      );

      // Service should NOT be started because bridge blocks it
      expect(svc.isActive, isFalse);
      expect(androidBridge.isTimerActive, isFalse);
      androidBridge.dispose();
    });

    tearDown(() {
      bridge.dispose();
    });
  });
}
