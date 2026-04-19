import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// ---------------------------------------------------------------------------
// Walk Timeline — reusable component for US-014 (full-screen) & US-015 (compact)
//
// Maps booking status strings to a 4-stage visual timeline:
//   Booked → Walker En Route → Walk Started → Walk Ended
// ---------------------------------------------------------------------------

/// The four stages of a walk timeline.
enum WalkTimelineStage {
  booked,
  walkerEnRoute,
  walkStarted,
  walkEnded;

  /// Maps a raw booking status string to the corresponding timeline stage.
  static WalkTimelineStage fromBookingStatus(String status) {
    switch (status) {
      case 'pending':
      case 'confirmed':
        return WalkTimelineStage.booked;
      case 'walker_en_route':
        return WalkTimelineStage.walkerEnRoute;
      case 'walk_started':
        return WalkTimelineStage.walkStarted;
      case 'walk_completed':
        return WalkTimelineStage.walkEnded;
      default:
        return WalkTimelineStage.booked;
    }
  }

  /// Full label for vertical (full-screen) layout.
  String get fullLabel {
    switch (this) {
      case WalkTimelineStage.booked:
        return 'Booked';
      case WalkTimelineStage.walkerEnRoute:
        return 'Walker En Route';
      case WalkTimelineStage.walkStarted:
        return 'Walk Started';
      case WalkTimelineStage.walkEnded:
        return 'Walk Ended';
    }
  }

  /// Short label for horizontal (compact) layout.
  String get shortLabel {
    switch (this) {
      case WalkTimelineStage.booked:
        return 'Booked';
      case WalkTimelineStage.walkerEnRoute:
        return 'En Route';
      case WalkTimelineStage.walkStarted:
        return 'Walking';
      case WalkTimelineStage.walkEnded:
        return 'Done';
    }
  }

  /// Whether this stage is completed relative to [currentStage].
  bool isCompleted(WalkTimelineStage currentStage) =>
      index < currentStage.index;

  /// Whether this stage is the current one.
  bool isCurrent(WalkTimelineStage currentStage) =>
      index == currentStage.index;

  /// Whether this stage is in the future.
  bool isFuture(WalkTimelineStage currentStage) =>
      index > currentStage.index;
}

/// Layout mode for the timeline.
enum WalkTimelineLayout { vertical, horizontal }

/// A reusable walk timeline widget that displays 4 stages.
///
/// Use [WalkTimelineLayout.vertical] for the full Active Walk screen (US-014)
/// and [WalkTimelineLayout.horizontal] for the compact home card (US-015).
class WalkTimeline extends StatelessWidget {
  const WalkTimeline({
    super.key,
    required this.currentStatus,
    this.layout = WalkTimelineLayout.vertical,
  });

  /// Raw booking status string (e.g. 'walk_started').
  final String currentStatus;

  /// Whether to render vertically (full-screen) or horizontally (compact).
  final WalkTimelineLayout layout;

  @override
  Widget build(BuildContext context) {
    final currentStage = WalkTimelineStage.fromBookingStatus(currentStatus);
    final stages = WalkTimelineStage.values;

    if (layout == WalkTimelineLayout.horizontal) {
      return _buildHorizontal(context, stages, currentStage);
    }
    return _buildVertical(context, stages, currentStage);
  }

  Widget _buildVertical(
    BuildContext context,
    List<WalkTimelineStage> stages,
    WalkTimelineStage currentStage,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < stages.length; i++) ...[
            _VerticalTimelineNode(
              stage: stages[i],
              currentStage: currentStage,
              isLast: i == stages.length - 1,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHorizontal(
    BuildContext context,
    List<WalkTimelineStage> stages,
    WalkTimelineStage currentStage,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          for (int i = 0; i < stages.length; i++) ...[
            Expanded(
              child: _HorizontalTimelineNode(
                stage: stages[i],
                currentStage: currentStage,
              ),
            ),
            if (i < stages.length - 1)
              Container(
                width: AppSpacing.md,
                height: 2,
                color: stages[i].isCompleted(currentStage) ||
                        stages[i].isCurrent(currentStage)
                    ? AppColors.goldenPaw
                    : AppColors.gray300,
              ),
          ],
        ],
      ),
    );
  }
}

/// A single node in the vertical timeline.
class _VerticalTimelineNode extends StatelessWidget {
  const _VerticalTimelineNode({
    required this.stage,
    required this.currentStage,
    required this.isLast,
  });

  final WalkTimelineStage stage;
  final WalkTimelineStage currentStage;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final completed = stage.isCompleted(currentStage);
    final current = stage.isCurrent(currentStage);

    final dotColor = completed
        ? AppColors.green500
        : current
            ? AppColors.goldenPaw
            : AppColors.gray300;

    final textColor = completed
        ? AppColors.textTertiary
        : current
            ? AppColors.textPrimary
            : AppColors.textTertiary;

    final fontWeight = current ? FontWeight.w800 : FontWeight.w600;

    return Column(
      key: ValueKey('timeline_node_${stage.name}'),
      children: [
        Row(
          children: [
            // Dot / check
            Container(
              key: ValueKey('timeline_dot_${stage.name}'),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
              child: completed
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : current
                      ? Icon(PhosphorIcons.dotOutline(PhosphorIconsStyle.fill),
                          size: 16, color: Colors.white)
                      : null,
            ),
            const SizedBox(width: AppSpacing.sm),
            // Label
            Expanded(
              child: Text(
                stage.fullLabel,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: fontWeight,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
        // Connector line (except for last node)
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 13),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 2,
                height: AppSpacing.lg,
                color: completed ? AppColors.green500 : AppColors.gray300,
              ),
            ),
          ),
      ],
    );
  }
}

/// A single node in the horizontal (compact) timeline.
class _HorizontalTimelineNode extends StatelessWidget {
  const _HorizontalTimelineNode({
    required this.stage,
    required this.currentStage,
  });

  final WalkTimelineStage stage;
  final WalkTimelineStage currentStage;

  @override
  Widget build(BuildContext context) {
    final completed = stage.isCompleted(currentStage);
    final current = stage.isCurrent(currentStage);

    final dotColor = completed
        ? AppColors.green500
        : current
            ? AppColors.goldenPaw
            : AppColors.gray300;

    final textColor = completed
        ? AppColors.textTertiary
        : current
            ? AppColors.textPrimary
            : AppColors.textTertiary;

    return Column(
      key: ValueKey('timeline_node_${stage.name}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: ValueKey('timeline_dot_${stage.name}'),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
          child: completed
              ? const Icon(Icons.check, size: 12, color: Colors.white)
              : null,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          stage.shortLabel,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: current ? FontWeight.w800 : FontWeight.w600,
            color: textColor,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// US-015: Compact card for the home screen with timeline + action buttons
// ---------------------------------------------------------------------------

/// A card widget for the home screen that shows a condensed walk timeline
/// with Map and Chat action buttons. Tapping the card navigates to the
/// full Active Walk screen.
class ActiveWalkTimelineCard extends StatelessWidget {
  const ActiveWalkTimelineCard({
    super.key,
    required this.bookingId,
    required this.bookingStatus,
    required this.walkerName,
    required this.dogName,
    required this.onTap,
    required this.onMapTap,
    required this.onChatTap,
  });

  final String bookingId;
  final String bookingStatus;
  final String walkerName;
  final String dogName;
  final VoidCallback onTap;
  final VoidCallback onMapTap;
  final VoidCallback onChatTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.green500, AppColors.emerald400],
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: [
            BoxShadow(
              color: AppColors.green500.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row: title + action buttons
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        walkerName,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Walking $dogName',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                // Map button
                _ActionIconButton(
                  key: const ValueKey('active_walk_card_map_btn'),
                  icon: PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                  onTap: onMapTap,
                  semanticLabel: 'View map',
                ),
                const SizedBox(width: AppSpacing.sm),
                // Chat button
                _ActionIconButton(
                  key: const ValueKey('active_walk_card_chat_btn'),
                  icon: PhosphorIcons.chatCircle(PhosphorIconsStyle.fill),
                  onTap: onChatTap,
                  semanticLabel: 'Open chat',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Timeline
            _CompactTimelineRow(currentStatus: bookingStatus),
          ],
        ),
      ),
    );
  }
}

/// Icon button used inside the active walk card.
class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

/// Compact horizontal timeline row styled for the green card background.
class _CompactTimelineRow extends StatelessWidget {
  const _CompactTimelineRow({required this.currentStatus});

  final String currentStatus;

  @override
  Widget build(BuildContext context) {
    final currentStage =
        WalkTimelineStage.fromBookingStatus(currentStatus);
    final stages = WalkTimelineStage.values;

    return Row(
      children: [
        for (int i = 0; i < stages.length; i++) ...[
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  key: ValueKey('timeline_dot_${stages[i].name}'),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: stages[i].isCompleted(currentStage)
                        ? Colors.white
                        : stages[i].isCurrent(currentStage)
                            ? AppColors.goldenPaw
                            : Colors.white.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: stages[i].isCompleted(currentStage)
                      ? Icon(Icons.check,
                          size: 12, color: AppColors.green600)
                      : null,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  stages[i].shortLabel,
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: stages[i].isCurrent(currentStage)
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: stages[i].isCurrent(currentStage) ||
                            stages[i].isCompleted(currentStage)
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (i < stages.length - 1)
            Container(
              width: AppSpacing.sm,
              height: 2,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              color: stages[i].isCompleted(currentStage) ||
                      stages[i].isCurrent(currentStage)
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.2),
            ),
        ],
      ],
    );
  }
}
