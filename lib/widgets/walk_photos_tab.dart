import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/widgets/paw_progress_indicator.dart';

/// Displays walk photos in the active walk screen's Photos tab.
///
/// Shows a [PawProgressIndicator] while loading, a friendly empty state
/// when there are no photos, and a grid of photo thumbnails when loaded.
class WalkPhotosTab extends StatelessWidget {
  const WalkPhotosTab({
    super.key,
    required this.isLoading,
    required this.photos,
    required this.isWalker,
    this.isUploading = false,
    this.onTakePhoto,
    this.onPhotoTap,
  });

  /// Whether photos are currently being fetched.
  final bool isLoading;

  /// The list of photo message records (each has `media_url`, `id`, etc.).
  final List<Map<String, dynamic>> photos;

  /// Whether the current user is the walker (shows camera button).
  final bool isWalker;

  /// Whether a photo upload is in progress.
  final bool isUploading;

  /// Called when the walker taps the Take Photo button.
  final VoidCallback? onTakePhoto;

  /// Called when a photo thumbnail is tapped, with the photo URL.
  final ValueChanged<String>? onPhotoTap;

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
            if (isWalker)
              GestureDetector(
                onTap: isUploading ? null : onTakePhoto,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 4,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.orange500,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: isUploading
                      ? const PawProgressIndicator(
                          size: 18,
                          strokeWidth: 2,
                          color: Colors.white,
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(PhosphorIcons.camera(),
                                size: 16, color: Colors.white),
                            const SizedBox(width: AppSpacing.xs),
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
        // Content area: loading / empty / grid
        if (isLoading)
          const _LoadingState()
        else if (photos.isEmpty)
          _EmptyState(
            isWalker: isWalker,
            onTakePhoto: onTakePhoto,
          )
        else
          _PhotoGrid(
            photos: photos,
            onPhotoTap: onPhotoTap,
          ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// Centered paw loader shown while photos are fetching.
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: PawProgressIndicator(),
      ),
    );
  }
}

/// Friendly empty state with paw icon and message.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.isWalker,
    this.onTakePhoto,
  });

  final bool isWalker;
  final VoidCallback? onTakePhoto;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isWalker ? onTakePhoto : null,
      child: Center(
        child: Column(
          children: [
            Icon(
              PhosphorIcons.pawPrint(),
              size: 48,
              color: AppColors.goldenPaw.withValues(alpha: 0.5),
              semanticLabel: 'No photos',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isWalker ? 'Tap to take a photo' : 'No photos yet',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grid of photo thumbnails.
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    this.onPhotoTap,
  });

  final List<Map<String, dynamic>> photos;
  final ValueChanged<String>? onPhotoTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        final url = photo['media_url'] as String?;
        if (url == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => onPhotoTap?.call(url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.sm),
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
