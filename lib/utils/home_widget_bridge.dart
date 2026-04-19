/// Bridge between booking status changes and Android Home Widget updates.
///
/// Accepts injectable [saveWidgetData] and [updateWidget] callbacks so that
/// the logic can be unit-tested without depending on the `home_widget` plugin.
/// In production, these callbacks wrap `HomeWidget.saveWidgetData<T>()` and
/// `HomeWidget.updateWidget()`.
class HomeWidgetBridge {
  HomeWidgetBridge({
    required this.saveWidgetData,
    required this.updateWidget,
  });

  /// Saves a key-value pair to the widget data store.
  final Future<void> Function(String key, dynamic value) saveWidgetData;

  /// Triggers the native widget to re-render.
  final Future<void> Function() updateWidget;

  /// End / cancellation statuses that clear the widget.
  static const _endStatuses = {
    'walk_completed',
    'cancelled',
    'cancelled_by_owner',
    'cancelled_by_walker',
    'rejected_by_walker',
  };

  /// Human-readable label for a booking status stage.
  static String stageLabel(String status) {
    switch (status) {
      case 'walker_en_route':
        return 'Walker en route';
      case 'walk_started':
        return 'Walk in progress';
      case 'walk_completed':
      case 'cancelled':
      case 'cancelled_by_owner':
      case 'cancelled_by_walker':
      case 'rejected_by_walker':
        return 'No active walk';
      default:
        return status;
    }
  }

  /// Called when booking status changes. Saves walker name, stage label,
  /// and elapsed time to the widget data store, then triggers a re-render.
  Future<void> onBookingStatusChanged({
    required String newStatus,
    required String walkerName,
    required String dogName,
    required int elapsedMinutes,
  }) async {
    final isEnded = _endStatuses.contains(newStatus);
    final displayStage = isEnded ? 'No active walk' : stageLabel(newStatus);

    await saveWidgetData('walkerName', isEnded ? '' : walkerName);
    await saveWidgetData('stage', displayStage);
    await saveWidgetData('elapsedMinutes', isEnded ? 0 : elapsedMinutes);
    await updateWidget();
  }

  /// Updates only the elapsed time without changing other fields.
  Future<void> updateElapsedTime({required int elapsedMinutes}) async {
    await saveWidgetData('elapsedMinutes', elapsedMinutes);
    await updateWidget();
  }
}
