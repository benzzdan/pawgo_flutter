import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/find_screen.dart' show AdvancedFilters;
import '../theme/app_theme.dart';
import 'range_slider_section.dart';

/// Bottom-sheet UI for the walker discovery filters described in Image-2
/// of the plan. Renders:
///
/// 1. Proximity range (km) — dual slider + "Only show walkers in this range"
///    toggle. Bound to [AdvancedFilters.minDistanceKm], `maxDistanceKm`, and
///    `onlyShowInRange`.
/// 2. Price range (MXN) — dual slider, bound to `minRate` / `maxRate`.
/// 3. Minimum experience — dropdown (0-10 years), bound to `minExperience`.
/// 4. Background checked — switch, bound to `backgroundChecked`.
/// 5. Reset / Apply CTAs at the bottom.
///
/// When the user taps Apply, the widget emits an [AdvancedFilters] via
/// [onApply]. Range bounds that sit at the slider's extreme are emitted as
/// NULL so the server-side RPC (migration 042) can treat them as "no
/// constraint on this side".
///
/// Per-control bounds (`_minDistance`, `_maxDistance`, `_minPrice`, `_maxPrice`)
/// are deliberately defined as `static const` so the sheet can be
/// pre-populated, edited, and re-instantiated without drift.
class WalkerFiltersSheet extends StatefulWidget {
  const WalkerFiltersSheet({
    super.key,
    required this.initial,
    required this.onApply,
    required this.onReset,
  });

  final AdvancedFilters initial;
  final ValueChanged<AdvancedFilters> onApply;
  final VoidCallback onReset;

  // Distance slider bounds in km. Anything at these extremes is treated as
  // "no constraint" when emitting back to the caller.
  static const double minDistanceBound = 0;
  static const double maxDistanceBound = 50;

  // Price slider bounds in MXN.
  static const double minPriceBound = 50;
  static const double maxPriceBound = 500;

  @override
  State<WalkerFiltersSheet> createState() => _WalkerFiltersSheetState();
}

class _WalkerFiltersSheetState extends State<WalkerFiltersSheet> {
  late RangeValues _distance;
  late RangeValues _price;
  late int _minExperience;
  late bool _backgroundChecked;
  late bool _onlyShowInRange;

  @override
  void initState() {
    super.initState();
    _distance = RangeValues(
      widget.initial.minDistanceKm ?? WalkerFiltersSheet.minDistanceBound,
      widget.initial.maxDistanceKm ?? WalkerFiltersSheet.maxDistanceBound,
    );
    _price = RangeValues(
      widget.initial.minRate ?? WalkerFiltersSheet.minPriceBound,
      widget.initial.maxRate ?? WalkerFiltersSheet.maxPriceBound,
    );
    _minExperience = widget.initial.minExperience ?? 0;
    _backgroundChecked = widget.initial.backgroundChecked ?? false;
    _onlyShowInRange = widget.initial.onlyShowInRange;
  }

  AdvancedFilters _toFilters() {
    // Treat values that sit at the slider's extreme as "no constraint" so
    // the RPC sees NULL and skips that side of the predicate.
    double? minDist = _distance.start > WalkerFiltersSheet.minDistanceBound
        ? _distance.start
        : null;
    double? maxDist = _distance.end < WalkerFiltersSheet.maxDistanceBound
        ? _distance.end
        : null;
    double? minRate = _price.start > WalkerFiltersSheet.minPriceBound
        ? _price.start
        : null;
    double? maxRate = _price.end < WalkerFiltersSheet.maxPriceBound
        ? _price.end
        : null;

    return AdvancedFilters(
      minDistanceKm: minDist,
      maxDistanceKm: maxDist,
      minRate: minRate,
      maxRate: maxRate,
      minExperience: _minExperience > 0 ? _minExperience : null,
      backgroundChecked: _backgroundChecked ? true : null,
      onlyShowInRange: _onlyShowInRange,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle.
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Advanced Filters',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // 1. Proximity range.
            RangeSliderSection(
              title: 'Proximity',
              unit: 'km',
              min: WalkerFiltersSheet.minDistanceBound,
              max: WalkerFiltersSheet.maxDistanceBound,
              values: _distance,
              divisions: 50,
              onChanged: (v) => setState(() => _distance = v),
              toggleLabel: 'Only show walkers in this range',
              toggleValue: _onlyShowInRange,
              onToggleChanged: (v) => setState(() => _onlyShowInRange = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            // 2. Price range.
            RangeSliderSection(
              title: 'Price',
              unit: 'MXN',
              min: WalkerFiltersSheet.minPriceBound,
              max: WalkerFiltersSheet.maxPriceBound,
              values: _price,
              divisions: 45,
              onChanged: (v) => setState(() => _price = v),
              valueLabelFormatter: (v) => '\$${v.round()}',
            ),
            const SizedBox(height: AppSpacing.lg),
            // 3. Minimum experience.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Minimum Experience',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                DropdownButton<int>(
                  value: _minExperience,
                  underline: const SizedBox(),
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  items: List.generate(11, (i) => i).map((yr) {
                    return DropdownMenuItem(
                      value: yr,
                      child: Text(yr == 0 ? 'Any' : '$yr+ years'),
                    );
                  }).toList(),
                  onChanged: (v) =>
                      setState(() => _minExperience = v ?? 0),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // 4. Background checked.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Background Checked',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Switch(
                  value: _backgroundChecked,
                  activeColor: AppColors.orange500,
                  onChanged: (v) => setState(() => _backgroundChecked = v),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // 5. Reset / Apply.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onReset,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: BorderSide(color: AppColors.gray400),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Reset',
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => widget.onApply(_toFilters()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange500,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Apply',
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
