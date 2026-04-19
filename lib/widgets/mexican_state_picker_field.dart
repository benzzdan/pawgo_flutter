import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawgo/constants/mexican_states.dart';
import 'package:pawgo/theme/app_theme.dart';

/// A tappable field that opens a scrollable bottom-sheet picker listing
/// all 32 Mexican states.  Replaces a free-text `TextField` so users
/// can only choose from the canonical list.
class MexicanStatePickerField extends StatelessWidget {
  /// Currently selected state, or `null` if none.
  final String? selectedState;

  /// Called with the chosen state string when the user taps one.
  final ValueChanged<String> onStateSelected;

  const MexicanStatePickerField({
    super.key,
    required this.selectedState,
    required this.onStateSelected,
  });

  Future<void> _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _MexicanStatePickerSheet(
        selectedState: selectedState,
      ),
    );
    if (result != null) {
      onStateSelected(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = selectedState != null && selectedState!.isNotEmpty;

    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasValue ? selectedState! : 'State',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: hasValue
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// The scrollable bottom-sheet content listing all 32 Mexican states.
class _MexicanStatePickerSheet extends StatelessWidget {
  final String? selectedState;

  const _MexicanStatePickerSheet({this.selectedState});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.85,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header with title and cancel
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select State',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // State list
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: mexicanStates.length,
                itemBuilder: (context, index) {
                  final state = mexicanStates[index];
                  final isSelected = state == selectedState;

                  return InkWell(
                    onTap: () => Navigator.pop(context, state),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              state,
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isSelected
                                    ? AppColors.orange500
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.orange500,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
