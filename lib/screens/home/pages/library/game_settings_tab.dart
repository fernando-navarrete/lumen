import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl2_flutter/common/clickable_container.dart';
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
          Column(
            spacing: AppSpacing.xs,
            children: [
              _VersionRow(
                label: protonState.defaultVersion != null
                    ? "Use global default (${protonState.defaultVersion})"
                    : "Use global default (none set)",
                isSelected: selectedTag == null,
                onTap: () => ref
                    .read(gamesStateProvider.notifier)
                    .setProtonVersion(gameId, null),
              ),
              for (final tag in protonState.installedTags)
                _VersionRow(
                  label: tag,
                  isSelected: selectedTag == tag,
                  onTap: () => ref
                      .read(gamesStateProvider.notifier)
                      .setProtonVersion(gameId, tag),
                ),
            ],
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

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ClickableContainer(
    onTap: onTap,
    child: Panel(
      selected: isSelected,
      child: Text(
        label,
        style: AppText.bodyMedium(color: Colors.white, weight: FontWeight.w600),
      ),
    ),
  );
}
