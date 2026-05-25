import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Formatter for the Min/Max value labels rendered above the slider.
/// Receives the underlying numeric value and returns the localized display
/// string. When omitted, [RangeSliderSection] falls back to "{value.round()}
/// {unit}".
typedef RangeValueFormatter = String Function(double value);

/// A reusable range-slider block — title row with unit chip, Min/Max value
/// labels, the [RangeSlider] itself, and (optionally) a labeled toggle below.
///
/// Used by `WalkerFiltersSheet` to express the Proximity and Price filters
/// from the Image-2 mockup. The unit chip + numeric labels mirror the
/// reference: a small pill next to the title shows the unit ("km", "MXN"),
/// and the Min/Max columns under it show the current range bounds.
class RangeSliderSection extends StatelessWidget {
  const RangeSliderSection({
    super.key,
    required this.title,
    required this.unit,
    required this.min,
    required this.max,
    required this.values,
    required this.onChanged,
    this.divisions,
    this.valueLabelFormatter,
    this.toggleLabel,
    this.toggleValue,
    this.onToggleChanged,
  }) : assert(
          (toggleLabel == null) == (onToggleChanged == null),
          'toggleLabel and onToggleChanged must be provided together',
        );

  final String title;

  /// Short unit string rendered in the chip next to the title and used as
  /// the suffix for the default Min/Max labels (e.g. "km", "MXN").
  final String unit;

  final double min;
  final double max;
  final RangeValues values;
  final ValueChanged<RangeValues> onChanged;

  /// Optional discrete-step count for the [RangeSlider]. Omit for smooth.
  final int? divisions;

  /// Optional override for how each numeric bound is rendered above the
  /// slider. Defaults to "{value.round()} {unit}".
  final RangeValueFormatter? valueLabelFormatter;

  /// Optional label for the toggle row rendered below the slider. When
  /// provided, [toggleValue] and [onToggleChanged] must also be provided.
  final String? toggleLabel;
  final bool? toggleValue;
  final ValueChanged<bool>? onToggleChanged;

  String _formatValue(double v) {
    if (valueLabelFormatter != null) return valueLabelFormatter!(v);
    return '${v.round()} $unit';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title + unit chip.
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.orange50,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                unit,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.orange500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Min / Max labels.
        Row(
          children: [
            Expanded(child: _ValueColumn(label: 'Min', value: _formatValue(values.start))),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _ValueColumn(
                label: 'Max',
                value: _formatValue(values.end),
                alignment: CrossAxisAlignment.end,
              ),
            ),
          ],
        ),
        // The slider itself.
        RangeSlider(
          values: values,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppColors.orange500,
          inactiveColor: AppColors.orange50,
          onChanged: onChanged,
        ),
        // Optional toggle row.
        if (toggleLabel != null) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  toggleLabel!,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Switch(
                value: toggleValue ?? false,
                activeColor: AppColors.orange500,
                onChanged: onToggleChanged,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ValueColumn extends StatelessWidget {
  const _ValueColumn({
    required this.label,
    required this.value,
    this.alignment = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
