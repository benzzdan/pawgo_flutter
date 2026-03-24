import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// A reusable bottom-sheet wrapper for the Pawgo design system.
///
/// Provides rounded top corners (24px), a drag handle indicator, smooth
/// slide-up animation, scrollable content support, drag-to-dismiss with
/// haptic feedback, and max height 90% of screen.
class PawgoBottomSheet extends StatelessWidget {
  const PawgoBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.fromLTRB(24, 0, 24, 24),
  });

  /// Optional title displayed below the drag handle.
  final String? title;

  /// The content of the bottom sheet.
  final Widget child;

  /// Padding around the content. Defaults to 24px on all sides except top.
  final EdgeInsets padding;

  /// Shows this bottom sheet as a modal with smooth slide-up animation.
  ///
  /// Returns the value passed to [Navigator.pop] when the sheet is dismissed.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    String? title,
    bool isDismissible = true,
    bool enableDrag = true,
    EdgeInsets padding = const EdgeInsets.fromLTRB(24, 0, 24, 24),
  }) {
    HapticFeedback.lightImpact();

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      builder: (sheetContext) => _HapticDismissListener(
        child: PawgoBottomSheet(
          title: title,
          padding: padding,
          child: builder(sheetContext),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle indicator
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Optional title
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                title!,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          // Scrollable content for long forms
          Flexible(
            child: SingleChildScrollView(
              padding: padding,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fires haptic feedback when the bottom sheet route is popped (dismissed).
class _HapticDismissListener extends StatefulWidget {
  const _HapticDismissListener({required this.child});

  final Widget child;

  @override
  State<_HapticDismissListener> createState() => _HapticDismissListenerState();
}

class _HapticDismissListenerState extends State<_HapticDismissListener> {
  @override
  void dispose() {
    // Haptic feedback on dismiss (drag or tap-outside)
    HapticFeedback.selectionClick();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
