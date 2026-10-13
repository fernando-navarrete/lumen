import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/clickable_container.dart';
import 'package:lumen/components/centered_loader.dart';
import 'package:lumen/components/panel.dart';
import 'package:lumen/components/primary_button.dart';
import 'package:lumen/components/refresh_chip.dart';
import 'package:lumen/components/retry_message.dart';
import 'package:lumen/models/game_build.dart';
import 'package:lumen/state/downloads_state.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/state/library_state.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

/// List of the game's available builds.
class BuildsTab extends ConsumerStatefulWidget {
  const BuildsTab({super.key, required this.gameId});

  final int gameId;

  @override
  ConsumerState<BuildsTab> createState() => _BuildsTabState();
}

class _BuildsTabState extends ConsumerState<BuildsTab> {
  Future<void> _reload() async {
    await ref.read(gogStateProvider).clearCache();
    if (!mounted) return;
    ref.invalidate(gameBuildsProvider(widget.gameId));
  }

  Future<void> _onBuildTap(GameBuild gameBuild) async {
    final gamesState = ref.read(gamesStateProvider);
    final gamesNotifier = ref.read(gamesStateProvider.notifier);
    final gameId = widget.gameId;
    final status = gamesState.getGameStatus(gameId);
    final runningTask = ref.read(downloadsStateProvider).tasks[gameId];

    if (status == GameStatus.downloading ||
        status == GameStatus.paused ||
        runningTask?.status == TaskStatus.running) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wait for the current task to finish")),
      );
      return;
    }

    if (status != GameStatus.downloaded) {
      // Not installed yet — just record the selection, nothing to repair.
      gamesNotifier.setSelectedBuild(gameId, gameBuild.versionName);
      return;
    }

    final isUpdate = ref.read(gameUpdateProvider(gameId)) == gameBuild;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _SwitchBuildDialog(
        versionName: gameBuild.versionName,
        isUpdate: isUpdate,
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final installPath = gamesState.getInstallPath(gameId);
    final productIds = gamesState.getProductIds(gameId).toList();
    if (installPath == null || productIds.isEmpty) {
      return;
    }

    await ref
        .read(downloadsStateProvider.notifier)
        .startRepairForInstalled(
          gameId,
          path: installPath,
          buildName: gameBuild.versionName,
          productIds: productIds,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${isUpdate ? 'Updating' : 'Switching build'} — check the "
            "Downloads tab for progress",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final buildsAsync = ref.watch(gameBuildsProvider(widget.gameId));
    final List<GameBuild>? builds = buildsAsync.value;
    final GameBuild? latest = builds == null ? null : latestBuild(builds);
    final GameBuild? update = ref.watch(gameUpdateProvider(widget.gameId));
    final gamesState = ref.watch(gamesStateProvider);
    final String? selectedName = gamesState.getSelectedBuild(widget.gameId);
    final int selectedBuild = selectedName == null
        ? -1
        : builds?.indexWhere((b) => b.versionName == selectedName) ?? -1;

    // The installed game has a recorded build that GOG no longer lists —
    // GOG delisted or renamed it after install. Surfaced as a note above the
    // list, since otherwise nothing being Active here looks unexplained (see
    // game_action_buttons.dart's `_checkBuild`, which blocks Verify/Play in
    // the same situation).
    final String? staleBuildName =
        gamesState.getGameStatus(widget.gameId) == GameStatus.downloaded &&
            builds != null &&
            selectedName != null &&
            selectedName.isNotEmpty &&
            selectedBuild == -1
        ? selectedName
        : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Select which build to install. Switching re-downloads the changed files.',
                        style: AppText.meta(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    RefreshChip(onTap: _reload),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (staleBuildName != null) ...[
                  Text(
                    'Installed build "$staleBuildName" is no longer listed '
                    'by GOG. Select the build to switch to — Lumen will '
                    'repair the install against it.',
                    style: AppText.meta(color: AppColors.error),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (buildsAsync.isLoading)
                  const CenteredLoader()
                else if (builds == null)
                  RetryMessage(
                    message: "Couldn't load builds.",
                    onRetry: _reload,
                  )
                else if (builds.isEmpty)
                  RetryMessage(
                    message: 'No builds available.',
                    onRetry: _reload,
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: builds.length,
                    itemBuilder: (context, index) => _BuildListItem(
                      isSelected: index == selectedBuild,
                      isLatest: builds[index] == latest,
                      isUpdate: builds[index] == update,
                      gameBuild: builds[index],
                      onTap: _onBuildTap,
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(width: _getTabWidth(size.width)),
      ],
    );
  }

  // NOTE: diverges from OverviewTab._getTabWidth (threshold 600 vs 1080,
  // exponent 1.5 vs 1.3) — preserved as-is from before the refactor.
  double _getTabWidth(double width) {
    final double tabWidth = width > 600 ? pow(width * 0.05, 1.5).toDouble() : 0;
    return tabWidth;
  }
}

/// Confirmation dialog shown before switching the build of an installed
/// game — the switch starts a repair against the new build, so it isn't a
/// silent, free action the way selecting a build for a not-yet-installed
/// game is.
class _SwitchBuildDialog extends StatelessWidget {
  const _SwitchBuildDialog({required this.versionName, required this.isUpdate});

  final String versionName;
  final bool isUpdate;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${isUpdate ? 'Update' : 'Switch'} to $versionName?',
                style: AppText.sectionLabel,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Lumen will re-download the files that changed for this build.',
                style: AppText.meta(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: AppSpacing.sm,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'Cancel',
                      style: AppText.button(color: AppColors.textSecondary),
                    ),
                  ),
                  PrimaryButton.icon(
                    icon: isUpdate ? Icons.system_update_alt : Icons.sync,
                    label: isUpdate ? 'Update' : 'Switch',
                    glowing: true,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quiet "↻ Refresh" chip re-fetching the build list.
class _BuildListItem extends StatelessWidget {
  const _BuildListItem({
    required this.gameBuild,
    required this.onTap,
    required this.isSelected,
    required this.isLatest,
    required this.isUpdate,
  });

  final GameBuild gameBuild;
  final Function(GameBuild) onTap;
  final bool isSelected;
  final bool isLatest;
  final bool isUpdate;

  @override
  Widget build(BuildContext context) {
    final releaseDate = gameBuild.releaseDate.replaceAll(RegExp(r'\+0000'), '');
    return ClickableContainer(
      onTap: () => onTap(gameBuild),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Panel(
          selected: isSelected,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            spacing: AppSpacing.md,
            children: [
              _RadioDot(selected: isSelected),
              Expanded(
                child: Column(
                  spacing: 3,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      spacing: AppSpacing.sm,
                      children: [
                        Text(gameBuild.versionName, style: AppText.cardTitle()),
                        if (isLatest)
                          Text(
                            'Latest',
                            style: AppText.onest(
                              size: 11,
                              weight: FontWeight.w600,
                              color: AppColors.primaryLight,
                            ),
                          ),
                      ],
                    ),
                    Text(releaseDate, style: AppText.cardDesc()),
                  ],
                ),
              ),
              isSelected
                  ? Text(
                      'Active',
                      style: AppText.onest(
                        size: 12.5,
                        weight: FontWeight.w600,
                        color: AppColors.primaryLight,
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.border08,
                        border: Border.all(color: AppColors.border14),
                        borderRadius: BorderRadius.circular(AppRadii.chip),
                      ),
                      child: Text(
                        isUpdate ? 'Update' : 'Switch',
                        style: AppText.onest(
                          size: 12.5,
                          weight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 18px radio circle: teal ring and dot when selected.
class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          width: 2,
          color: selected ? AppColors.primary : AppColors.textMuted,
        ),
      ),
      child: selected
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
            )
          : null,
    );
  }
}
