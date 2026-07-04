import 'package:flutter/material.dart';
import 'package:gogdl2_flutter/components/centered_loader.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';
import 'package:gogdl2_flutter/theme/app_dimens.dart';

/// Resolves [imageUrl] and renders it filling its bounds, clipped to
/// [borderRadius]. Shows a spinner while pending and a subtle fill on error.
class AsyncCoverImage extends StatelessWidget {
  const AsyncCoverImage({
    super.key,
    required Future<String> this.imageUrl,
    this.borderRadius = AppRadii.card,
    this.fit = BoxFit.cover,
  }) : resolvedUrl = null;

  /// For URLs that are already resolved, e.g. screenshot links.
  const AsyncCoverImage.resolved(
    String this.resolvedUrl, {
    super.key,
    this.borderRadius = AppRadii.card,
    this.fit = BoxFit.cover,
  }) : imageUrl = null;

  final Future<String>? imageUrl;
  final String? resolvedUrl;
  final double borderRadius;
  final BoxFit fit;

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

  Widget _image(String url) => Image.network(
    url,
    fit: fit,
    errorBuilder: (context, error, stackTrace) =>
        const ColoredBox(color: AppColors.fill08),
  );
}
