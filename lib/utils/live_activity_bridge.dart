import 'dart:async';
import 'package:pawgo/services/live_activity_service.dart';

/// Statuses that trigger starting a Live Activity.
const _startStatuses = {'walker_en_route', 'walk_started'};

/// Statuses that trigger ending a Live Activity.
const _endStatuses = {
  'walk_completed',
  'cancelled',
  'cancelled_by_owner',
  'cancelled_by_walker',
  'rejected_by_walker',
};

/// Bridge between booking status changes and [LiveActivityService].
///
/// Encapsulates the platform guard and timer logic so that both the
/// ActiveWalkScreen integration and unit tests can use a shared,
/// deterministic code path.
class LiveActivityBridge {
  LiveActivityBridge({
    required this.service,
    required bool isPlatformSupported,
  }) : _isPlatformSupported = isPlatformSupported;

  final LiveActivityService service;
  final bool _isPlatformSupported;

  Timer? _updateTimer;
  int _elapsedMinutes = 0;
  DateTime? _walkStartedAt;

  /// Whether the periodic update timer is currently running.
  bool get isTimerActive => _updateTimer?.isActive ?? false;

  /// Called when the booking status changes. Starts, updates, or ends
  /// the Live Activity as appropriate.
  ///
  /// On non-iOS platforms (when [_isPlatformSupported] is false), this
  /// method returns immediately without side effects.
  Future<void> onBookingStatusChanged({
    required String newStatus,
    required String walkerName,
    required String dogName,
  }) async {
    if (!_isPlatformSupported) return;

    if (_startStatuses.contains(newStatus)) {
      await service.start(
        walkerName: walkerName,
        dogName: dogName,
        stage: newStatus,
      );

      // Start periodic updates only during walk_started
      if (newStatus == 'walk_started') {
        _walkStartedAt = DateTime.now();
        _elapsedMinutes = 0;
        _startUpdateTimer();
      }
    } else if (_endStatuses.contains(newStatus)) {
      _stopUpdateTimer();
      await service.end();
    }
  }

  /// Manually set elapsed minutes (for resuming a walk mid-progress).
  void setElapsedMinutes(int minutes) {
    _elapsedMinutes = minutes;
  }

  /// Manually set walk start time (for resuming).
  void setWalkStartedAt(DateTime? startedAt) {
    _walkStartedAt = startedAt;
  }

  void _startUpdateTimer() {
    _stopUpdateTimer();
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_walkStartedAt != null) {
        _elapsedMinutes =
            DateTime.now().difference(_walkStartedAt!).inMinutes;
      } else {
        _elapsedMinutes++;
      }
      service.update(
        stage: 'walk_started',
        elapsedMinutes: _elapsedMinutes,
      );
    });
  }

  void _stopUpdateTimer() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  /// Clean up timer resources.
  void dispose() {
    _stopUpdateTimer();
  }
}
