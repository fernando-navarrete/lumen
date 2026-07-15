import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/clickable_container.dart';
import 'package:lumen/components/async_cover_image.dart';
import 'package:lumen/components/bounce_marquee.dart';
import 'package:lumen/components/gradient_progress_bar.dart';
import 'package:lumen/state/downloads_state.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_decorations.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

class GameCard extends ConsumerWidget {
  final int? gameId;
  final String gameName;
  final VoidCallback? onTap;

  const GameCard({super.key, this.gameId, required this.gameName, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GameStatus status = ref.watch(
      gamesStateProvider.select((state) => state.getGameStatus(gameId!)),
    );
    // Select a value-type snapshot of the bytes rather than the ActivityTask
    // instance itself: the notifier mutates that instance in place, so
    // `select` would see the same reference across updates (no `==`
    // override) and this card would never rebuild while downloading.
    final (int, int)? progress = ref.watch(
      downloadsStateProvider.select((state) {
        final task = state.tasks[gameId!];
        return task == null ? null : (task.downloadedBytes, task.totalBytes);
      }),
    );

    Widget cover = AsyncCoverImage(
      imageUrl: ref.watch(gogStateProvider).getGameBoxartLink(gameId!),
    );
    if (status == GameStatus.notInstalled) {
      cover = ColorFiltered(
        colorFilter: AppDecorations.dimmedCover,
        child: cover,
      );
    }

    return ClickableContainer(
      onTap: onTap,
      child: Container(
        decoration: AppDecorations.card(borderColor: AppColors.border09),
        child: Stack(
          children: [
            Positioned.fill(child: cover),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(11, 26, 11, 11),
                decoration: AppDecorations.cardScrim.copyWith(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(AppRadii.card),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 5,
                  children: [
                    AutoMarqueeText(
                      text: gameName,
                      style: AppText.bodyMedium(
                        color: Colors.white,
                        weight: FontWeight.w600,
                      ),
                    ),
                    _statusLine(status, progress),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Status pill per design; while installing, a tiny progress bar with an
  /// "Installing · NN%" row replaces the pill.
  Widget _statusLine(GameStatus status, (int, int)? progress) {
    if (status == GameStatus.downloading &&
        progress != null &&
        progress.$2 > 0) {
      final double fraction = progress.$1 / progress.$2;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 5,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Installing',
                style: AppText.onest(
                  size: 10,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                '${(fraction * 100).round()}%',
                style: AppText.onest(
                  size: 10,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          GradientProgressBar(value: fraction, height: 4),
        ],
      );
    }

    final (String label, Color color) = switch (status) {
      GameStatus.downloading => ("● Installing", AppColors.primaryLight),
      GameStatus.downloaded => ("● Installed", AppColors.primaryLight),
      GameStatus.notInstalled => ("↓ Not installed", AppColors.text70),
    };
    return Text(label, style: AppText.statusPill(color: color));
  }
}
