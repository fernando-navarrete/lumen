import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl2_flutter/components/app_dropdown.dart';
import 'package:gogdl2_flutter/components/panel.dart';
import 'package:gogdl2_flutter/state/games_state.dart';
import 'package:gogdl2_flutter/state/proton_state.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';
import 'package:gogdl2_flutter/theme/app_dimens.dart';
import 'package:gogdl2_flutter/theme/text_styles.dart';

/// Per-game settings: override which Proton-GE version this game launches
/// with (falling back to the global default from the Settings screen when
/// unset), and show the game's Proton prefix directory.
class GameSettingsTab extends ConsumerWidget {
  const GameSettingsTab({super.key, required this.gameId});

  final int gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final protonState = ref.watch(protonStateProvider);
    final gamesState = ref.watch(gamesStateProvider);
    final selectedTag = gamesState.getProtonVersion(gameId);
    final prefixPath = gamesState.getProtonPrefixPath(gameId);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Proton version", style: AppText.sectionLabel),
          const SizedBox(height: AppSpacing.sm),
          AppDropdown<String?>(
            value: selectedTag,
            entries: [
              AppDropdownEntry(
                value: null,
                label: protonState.defaultVersion != null
                    ? "Use global default (${protonState.defaultVersion})"
                    : "Use global default (none set)",
              ),
              for (final tag in protonState.installedTags)
                AppDropdownEntry(value: tag, label: tag),
            ],
            onChanged: (tag) => ref
                .read(gamesStateProvider.notifier)
                .setProtonVersion(gameId, tag),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text("Proton prefix", style: AppText.sectionLabel),
          const SizedBox(height: AppSpacing.sm),
          Panel(
            child: Text(
              prefixPath ?? "Created automatically the first time you play.",
              style: AppText.bodyMedium(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
