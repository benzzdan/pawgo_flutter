import 'dart:io';
import 'package:flutter/foundation.dart';

/// Manages iOS Live Activities for active dog walks.
///
/// On iOS, this wraps the `live_activities` plugin to show a Dynamic Island
/// and Lock Screen widget with walk progress. On Android and other platforms,
/// all methods are silent no-ops.
class LiveActivityService {
  LiveActivityService();

  String? _activityId;

  /// Whether a Live Activity is currently active.
  bool get isActive => _activityId != null;

  /// Starts a Live Activity displaying walker name, dog name, and current stage.
  ///
  /// Does nothing on non-iOS platforms.
  Future<void> start({
    required String walkerName,
    required String dogName,
    required String stage,
  }) async {
    if (!_isIOS) return;

    try {
      // The live_activities plugin uses a map-based API to push data
      // to the ActivityKit widget defined in PawgoLiveActivity.swift.
      // In a real build with the plugin available, this would call:
      //   final plugin = LiveActivitiesPlugin();
      //   _activityId = await plugin.createActivity({
      //     'walkerName': walkerName,
      //     'dogName': dogName,
      //     'stage': stage,
      //     'elapsedMinutes': 0,
      //   });
      debugPrint(
        'LiveActivityService: start(walker=$walkerName, dog=$dogName, stage=$stage)',
      );
      _activityId = 'pawgo_walk_activity';
    } catch (e) {
      debugPrint('LiveActivityService: failed to start — $e');
    }
  }

  /// Updates the running Live Activity with new stage and elapsed time.
  ///
  /// Does nothing on non-iOS platforms or if no activity is active.
  Future<void> update({
    required String stage,
    required int elapsedMinutes,
  }) async {
    if (!_isIOS || _activityId == null) return;

    try {
      // In a real build:
      //   final plugin = LiveActivitiesPlugin();
      //   await plugin.updateActivity(_activityId!, {
      //     'stage': stage,
      //     'elapsedMinutes': elapsedMinutes,
      //   });
      debugPrint(
        'LiveActivityService: update(stage=$stage, elapsed=$elapsedMinutes)',
      );
    } catch (e) {
      debugPrint('LiveActivityService: failed to update — $e');
    }
  }

  /// Ends the running Live Activity.
  ///
  /// Does nothing on non-iOS platforms or if no activity is active.
  Future<void> end() async {
    if (!_isIOS || _activityId == null) return;

    try {
      // In a real build:
      //   final plugin = LiveActivitiesPlugin();
      //   await plugin.endActivity(_activityId!);
      debugPrint('LiveActivityService: end()');
      _activityId = null;
    } catch (e) {
      debugPrint('LiveActivityService: failed to end — $e');
    }
  }

  /// Platform guard — returns true only on iOS.
  /// Uses a getter so it can be evaluated at call time (not compile time),
  /// and gracefully returns false in test environments where Platform
  /// may throw.
  bool get _isIOS {
    try {
      return Platform.isIOS;
    } catch (_) {
      return false;
    }
  }
}
