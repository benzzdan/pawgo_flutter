import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pawgo/config/env.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/utils/media_url_rewriter.dart';
import 'package:pawgo/widgets/paw_progress_indicator.dart';

/// Renders a walk-media image with the URL-host rewriter, an `apikey` header,
/// a centered loading spinner, and a graceful broken-image fallback.
///
/// Single source of truth for in-walk chat photo rendering. Use this anywhere
/// a Supabase walk-media URL is displayed (chat bubbles, photo grids,
/// full-screen viewers) so the URL rewriter and apikey header stay in sync.
///
/// Override [errorBuilder] when a specific surface needs a different broken
/// image treatment (e.g. white-on-black icon on a full-screen viewer); the
/// default renders a muted icon on a [AppColors.surface] background suitable
/// for thumbnails and chat bubbles.
class ChatMediaImage extends StatelessWidget {
  const ChatMediaImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorBuilder,
    this.errorIconSize = 32,
    this.apiKey,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  /// Icon size used by the default [errorBuilder]. Ignored when [errorBuilder]
  /// is supplied.
  final double errorIconSize;

  /// Override the apikey header value. Defaults to
  /// [Env.current.supabaseAnonKey] so callers normally don't need to set this.
  final String? apiKey;

  @override
  Widget build(BuildContext context) {
    final rewritten =
        rewriteMediaUrl(url, supabaseUrl: Env.current.supabaseUrl) ?? url;
    return Image.network(
      rewritten,
      fit: fit,
      width: width,
      height: height,
      headers: {'apikey': apiKey ?? Env.current.supabaseAnonKey},
      loadingBuilder: (ctx, child, progress) => progress == null
          ? child
          : const Center(child: PawProgressIndicator(size: 24)),
      errorBuilder: errorBuilder ??
          (ctx, error, stack) => Container(
                width: width,
                height: height,
                color: AppColors.surface,
                child: Center(
                  child: Icon(
                    PhosphorIcons.imageBroken(),
                    size: errorIconSize,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
    );
  }
}
