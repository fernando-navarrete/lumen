import 'package:flutter/material.dart';
import 'package:lumen/components/centered_loader.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';

/// Resolves [imageUrl] and renders it filling its bounds, clipped to
/// [borderRadius]. Shows a spinner while pending and a subtle fill on error.
///
/// With [decodeAtLayoutWidth] the image is decoded no wider than its box
/// (times the device pixel ratio) instead of at full resolution. That is only
/// right when the image is width-bound under [BoxFit.cover], i.e. no wider
/// relative to its height than the box; otherwise it would decode too small.
class AsyncCoverImage extends StatelessWidget {
  const AsyncCoverImage({
    super.key,
    required Future<String> this.imageUrl,
    this.borderRadius = AppRadii.card,
    this.fit = BoxFit.cover,
    this.decodeAtLayoutWidth = false,
  }) : resolvedUrl = null;

  /// For URLs that are already resolved, e.g. screenshot links.
  const AsyncCoverImage.resolved(
    String this.resolvedUrl, {
    super.key,
    this.borderRadius = AppRadii.card,
    this.fit = BoxFit.cover,
    this.decodeAtLayoutWidth = false,
  }) : imageUrl = null;

  final Future<String>? imageUrl;
  final String? resolvedUrl;
  final double borderRadius;
  final BoxFit fit;
  final bool decodeAtLayoutWidth;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: resolvedUrl != null
          ? _image(resolvedUrl!)
          : FutureBuilder<String>(
              future: imageUrl,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const ColoredBox(color: AppColors.fill08);
                }
                if (snapshot.hasData) {
                  return _image(snapshot.data!);
                }
                return const CenteredLoader();
              },
            ),
    );
  }

  Widget _image(String url) {
    Widget build(int? cacheWidth) => Image.network(
      url,
      fit: fit,
      cacheWidth: cacheWidth,
      errorBuilder: (context, error, stackTrace) =>
          const ColoredBox(color: AppColors.fill08),
    );
    if (!decodeAtLayoutWidth) return build(null);
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final int? cacheWidth = width.isFinite && width > 0
            ? (width * MediaQuery.devicePixelRatioOf(context)).ceil()
            : null;
        return build(cacheWidth);
      },
    );
  }
}
