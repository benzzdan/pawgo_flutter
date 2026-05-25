import 'package:flutter/material.dart';
import 'package:pawgo/l10n/app_localizations.dart';
import 'package:pawgo/models/temperament.dart';
import 'package:pawgo/theme/app_theme.dart';

/// Face-card temperament picker. Renders one card per [Temperament] value
/// with its emoji and localized label. The selected card has a thicker
/// border and a warm tint.
class MoodPicker extends StatelessWidget {
  final Temperament? value;
  final ValueChanged<Temperament> onChanged;
  const MoodPicker({super.key, required this.value, required this.onChanged});

  String _label(BuildContext ctx, Temperament t) {
    final l10n = AppLocalizations.of(ctx);
    switch (t) {
      case Temperament.calm:
        return l10n.moodCalm;
      case Temperament.playful:
        return l10n.moodPlayful;
      case Temperament.shy:
        return l10n.moodShy;
      case Temperament.anxious:
        return l10n.moodAnxious;
      case Temperament.passiveAggressive:
        return l10n.moodPassiveAggressive;
      case Temperament.reactive:
        return l10n.moodReactive;
      case Temperament.aggressive:
        return l10n.moodAggressive;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: Temperament.values.map((t) {
        final selected = t == value;
        return InkWell(
          onTap: () => onChanged(t),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 96,
            height: 128,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.goldenPaw.withValues(alpha: 0.18)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.cacaoBrown : Colors.black12,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(t.emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(height: 6),
                Flexible(
                  child: Text(
                    _label(context, t),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
