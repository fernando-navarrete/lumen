import 'package:flutter/material.dart';

/// Resolves [imageUrl] and renders it filling its bounds, clipped to
/// [borderRadius]. Renders nothing while the future is pending or fails.
class AsyncCoverImage extends StatelessWidget {
  const AsyncCoverImage({
    super.key,
    required this.imageUrl,
    this.borderRadius = 13.0,
  });

  final Future<String> imageUrl;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: FutureBuilder<String>(
        future: imageUrl,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.network(snapshot.data!, fit: BoxFit.cover);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
