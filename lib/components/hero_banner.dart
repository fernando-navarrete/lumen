import 'package:flutter/material.dart';
import 'package:lumen/components/async_cover_image.dart';
import 'package:lumen/theme/app_decorations.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

/// Wide 300px banner over a game's background art: mono eyebrow, huge
/// title, a meta row and an action row, all over a left-to-right scrim.
/// Used by the library's featured game and the game detail header.
class HeroBanner extends StatelessWidget {
  const HeroBanner({
    super.key,
    required this.imageUrl,
    this.eyebrow,
    required this.title,
    this.metaChildren = const [],
    this.actions = const [],
  });

  final Future<String> imageUrl;

  /// Uppercase mono label over the title, e.g. "CONTINUE PLAYING".
  final String? eyebrow;
  final String title;

  /// 13px spans shown between title and actions (status, version, ...).
  final List<Widget> metaChildren;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: AppDecorations.heroCard,
      child: Stack(
        children: [
          Positioned.fill(
            child: AsyncCoverImage(
              imageUrl: imageUrl,
              borderRadius: AppRadii.hero,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(decoration: AppDecorations.heroScrim()),
          ),
          Positioned(
            left: 38,
            top: 0,
            bottom: 0,
            right: 38,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (eyebrow != null) ...[
                  Text(eyebrow!, style: AppText.eyebrow),
                  const SizedBox(height: 14),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Text(
                    title,
                    style: AppText.heroTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (metaChildren.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(spacing: 14, children: metaChildren),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Row(spacing: 12, children: actions),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
