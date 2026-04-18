import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pawgo/theme/app_theme.dart';

/// Extracted Photos tab content for the Active Walk screen.
///
/// Shows a paw-print rotating loader during fetch, an empty-state message
/// when no photos exist, or a photo grid once photos arrive.
class WalkPhotosTab extends StatefulWidget {
  const WalkPhotosTab({
    super.key,
    required this.photos,
    required this.isLoading,
    required this.isWalker,
    this.onTakePhoto,
    this.isUploadingPhoto = false,
    this.onPhotoTap,
  });

  final List<Map<String, dynamic>> photos;
  final bool isLoading;
  final bool isWalker;
  final VoidCallback? onTakePhoto;
  final bool isUploadingPhoto;
  final void Function(String url)? onPhotoTap;

  @override
  State<WalkPhotosTab> createState() => _WalkPhotosTabState();
}

class _WalkPhotosTabState extends State<WalkPhotosTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Walk Photos',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            if (widget.isWalker && !widget.isLoading)
              GestureDetector(
                onTap: widget.isUploadingPhoto ? null : widget.onTakePhoto,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.orange500,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: widget.isUploadingPhoto
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(PhosphorIcons.camera(),
                                size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Take Photo',
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Content area
        if (widget.isLoading)
          _buildPawLoader()
        else if (widget.photos.isEmpty)
          _buildEmptyState()
        else
          _buildPhotoGrid(),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _buildPawLoader() {
    return Center(
      key: const Key('paw_loader'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: AnimatedBuilder(
          animation: _rotationController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationController.value * 2 * math.pi,
              child: child,
            );
          },
          child: Icon(
            PhosphorIcons.pawPrint(),
            size: 48,
            color: AppColors.warmCaramel,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          children: [
            Icon(
              PhosphorIcons.camera(),
              size: 48,
              color: AppColors.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.isWalker
                  ? 'Tap to take a photo'
                  : 'No photos yet — the walker will share moments from the walk!',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemCount: widget.photos.length,
      itemBuilder: (context, index) {
        final photo = widget.photos[index];
        final url = photo['media_url'] as String?;
        if (url == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => widget.onPhotoTap?.call(url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surface,
                child: Center(
                  child: Icon(
                    PhosphorIcons.imageBroken(),
                    size: 24,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Tab button for the Photos tab that supports a new-photo badge dot.
///
/// The badge only appears when [hasNewPhotos] is true AND [isSelected] is false.
/// This ensures the badge clears when the owner switches to the Photos tab.
class WalkPhotosTabButton extends StatelessWidget {
  const WalkPhotosTabButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.hasNewPhotos,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final bool hasNewPhotos;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Colors.white : AppColors.textSecondary;
    final showBadge = hasNewPhotos && !isSelected;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.orange500 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.orange500.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      label,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                if (showBadge)
                  Positioned(
                    key: const Key('new_photo_badge'),
                    top: -3,
                    right: -8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.red500,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
