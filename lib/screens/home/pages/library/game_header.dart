import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/components/game_action_buttons.dart';
import 'package:lumen/components/hero_banner.dart';
import 'package:lumen/components/primary_button.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/state/proton_state.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/text_styles.dart';

/// Wide banner with the game's background art, title, status meta row and
/// the status-driven action buttons.
class GameHeader extends ConsumerWidget {
  const GameHeader({
    super.key,
    required this.gameId,
    this.onConfigure,
    this.onSelectBuild,
  });

  final int gameId;

  /// Invoked by the Configure button, e.g. to jump to the Settings tab.
  final VoidCallback? onConfigure;

  /// Forwarded to [GameActionButtons.onSelectBuild].
  final VoidCallback? onSelectBuild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gogState = ref.watch(gogStateProvider);
    final gamesState = ref.watch(gamesStateProvider);
    final GameStatus status = gamesState.getGameStatus(gameId);

    final (String statusLabel, Color statusColor) = switch (status) {
      GameStatus.downloading => ("● Installing", AppColors.primaryLight),
      GameStatus.downloaded => ("● Installed", AppColors.primaryLight),
      GameStatus.notInstalled => ("↓ Not installed", AppColors.text70),
    };

    final String? buildVersion = gamesState.getSelectedBuild(gameId);
    final String? proton =
        gamesState.getProtonVersion(gameId) ??
        ref.watch(protonStateProvider).defaultVersion;

    return FutureBuilder<String?>(
      future: gogState.getGameName(gameId),
      builder: (context, snapshot) {
        return HeroBanner(
          imageUrl: gogState.getGameBackgroundLink(gameId),
          title: snapshot.data ?? 'Loading...',
          metaChildren: [
            Text(
              statusLabel,
              style: AppText.meta(color: statusColor, weight: FontWeight.w600),
            ),
            if (buildVersion != null && buildVersion.isNotEmpty)
              Text(buildVersion, style: AppText.meta()),
            if (proton != null)
              Row(
                spacing: 6,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(proton, style: AppText.meta()),
                ],
              ),
          ],
          actions: [
            GameActionButtons(
              gameId: gameId,
              large: true,
              onSelectBuild: onSelectBuild,
            ),
            if (onConfigure != null)
              PrimaryButton(
                onTap: onConfigure!,
                large: true,
                child: Text(
                  "Configure",
                  style: AppText.button(color: Colors.white),
                ),
              ),
          ],
        );
      },
    );
  }
}
