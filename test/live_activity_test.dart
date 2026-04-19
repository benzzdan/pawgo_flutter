import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/services/live_activity_service.dart';

void main() {
  group('LiveActivityService', () {
    late LiveActivityService service;

    setUp(() {
      service = LiveActivityService();
    });

    test('exists and can be instantiated', () {
      expect(service, isNotNull);
      expect(service, isA<LiveActivityService>());
    });

    test('start() accepts walkerName, dogName, and stage parameters', () async {
      // Verify start method exists with expected signature.
      // On non-iOS platforms this is a no-op, so it should complete without error.
      await service.start(
        walkerName: 'Maria',
        dogName: 'Rex',
        stage: 'walker_en_route',
      );
    });

    test('update() accepts stage and elapsedMinutes parameters', () async {
      // Verify update method exists with expected signature.
      await service.update(
        stage: 'walk_started',
        elapsedMinutes: 15,
      );
    });

    test('end() completes without error', () async {
      // Verify end method exists.
      await service.end();
    });
  });
}
