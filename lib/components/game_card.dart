import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl2_flutter/common/clickable_container.dart';
import 'package:gogdl2_flutter/components/async_cover_image.dart';
import 'package:gogdl2_flutter/components/bounce_marquee.dart';
import 'package:gogdl2_flutter/state/gog_state.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';
import 'package:gogdl2_flutter/theme/app_decorations.dart';
import 'package:gogdl2_flutter/theme/text_styles.dart';

class GameCard extends ConsumerWidget {
  final int? gameId;
  final String gameName;
  final VoidCallback? onTap;

  const GameCard({super.key, this.gameId, required this.gameName, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClickableContainer(
      onTap: onTap,
      child: Container(
        decoration: AppDecorations.card(
          borderRadius: 13.0,
          borderColor: AppColors.border12,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AsyncCoverImage(
                imageUrl: ref
                    .watch(gogStateProvider)
                    .getGameBoxartLink(gameId!),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 56,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(0),
                      Colors.black.withAlpha(196),
                      Colors.black.withAlpha(255),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoMarqueeText(
                      text: gameName,
                      style: TextStyle(color: Colors.white),
                    ),
                    Text(
                      "Not installed",
                      style: AppText.onest(
                        size: 12,
                        color: Colors.grey,
                        weight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
