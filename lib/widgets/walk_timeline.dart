import 'package:flutter/material.dart';
import 'package:pawgo/theme/app_theme.dart';

/// A vertical 4-stage timeline showing booking progress.
///
/// Stages: Booked -> Walker En Route -> Walk Started -> Walk Ended
///
/// Status-to-stage mapping:
/// - `pending` (default) -> stage 0 (Booked) is current
/// - `confirmed` / `walker_en_route` -> stage 1 (Walker En Route) is current
/// - `walk_started` -> stage 2 (Walk Started) is current
/// - `walk_completed` -> stage 3 (Walk Ended) is current, all completed
class WalkTimeline extends StatelessWidget {
  const WalkTimeline({super.key, required this.status});

  /// The raw booking status string from the database.
  final String status;

  static const _stages = [
    'Booked',
    'Walker En Route',
    'Walk Started',
    'Walk Ended',
  ];

  /// Returns the index of the currently active stage (0-based).
  int get _activeStageIndex {
    switch (status) {
      case 'confirmed':
      case 'walker_en_route':
        return 1;
      case 'walk_started':
        return 2;
      case 'walk_completed':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _activeStageIndex;
    // For walk_completed, all stages are completed (no "current" stage).
    final allCompleted = status == 'walk_completed';

    return Semantics(
      label: 'Walk progress: ${_stages[activeIndex]}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < _stages.length; i++) ...[
            _TimelineStep(
              label: _stages[i],
              state: allCompleted
                  ? _StepState.completed
                  : i < activeIndex
                      ? _StepState.completed
                      : i == activeIndex
                          ? _StepState.current
                          : _StepState.future,
              isLast: i == _stages.length - 1,
            ),
          ],
        ],
      ),
    );
  }
}

enum _StepState { completed, current, future }

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.state,
    required this.isLast,
  });

  final String label;
  final _StepState state;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Indicator column: circle + connector line
        SizedBox(
          width: 32,
          child: Column(
            children: [
              _buildCircle(isDark),
              if (!isLast) _buildConnector(isDark),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Label
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              top: 2,
              bottom: isLast ? 0 : AppSpacing.xs,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    state == _StepState.current ? FontWeight.w700 : FontWeight.w600,
                color: _labelColor(isDark),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircle(bool isDark) {
    const size = 24.0;

    switch (state) {
      case _StepState.completed:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: AppColors.goldenPaw,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 14, color: Colors.white),
        );
      case _StepState.current:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.goldenPaw,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.goldenPaw.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      case _StepState.future:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.gray300,
              width: 2,
            ),
          ),
        );
    }
  }

  Widget _buildConnector(bool isDark) {
    final isActive = state == _StepState.completed || state == _StepState.current;
    return Container(
      width: 2,
      height: 24,
      color: isActive
          ? AppColors.goldenPaw
          : (isDark ? AppColors.darkBorder : AppColors.gray300),
    );
  }

  Color _labelColor(bool isDark) {
    switch (state) {
      case _StepState.completed:
        return isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
      case _StepState.current:
        return AppColors.goldenPaw;
      case _StepState.future:
        return isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;
    }
  }
}
