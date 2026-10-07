import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/clickable_container.dart';
import 'package:lumen/components/centered_loader.dart';
import 'package:lumen/components/panel.dart';
import 'package:lumen/components/primary_button.dart';
import 'package:lumen/models/game_build.dart';
import 'package:lumen/state/downloads_state.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_decorations.dart';
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
  bool _loading = true;
  List<GameBuild>? _builds;
  int selectedBuild = -1;

  /// Set when the game is installed, has a non-empty recorded build, but
  /// that build isn't in [_builds] — GOG delisted or renamed it after
  /// install. Surfaced as a note above the list, since otherwise nothing
  /// being Active here looks unexplained (see game_action_buttons.dart's
  /// `_checkBuild`, which blocks Verify/Play in the same situation).
  String? _staleBuildName;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBuilds());
    super.initState();
  }

  Future<void> _loadBuilds() async {
    setState(() => _loading = true);
    final GogState gogState = ref.read(gogStateProvider);
    final builds = await gogState.getBuilds(widget.gameId);
    if (!mounted) return;

    final GamesState gamesState = ref.read(gamesStateProvider);
    final String? selectedName = gamesState.getSelectedBuild(widget.gameId);
    final installed =
        gamesState.getGameStatus(widget.gameId) == GameStatus.downloaded;
    final index = selectedName == null
        ? -1
        : builds?.indexWhere((b) => b.versionName == selectedName) ?? -1;
    setState(() {
      _builds = builds;
      selectedBuild = index;
      _staleBuildName =
          installed &&
              builds != null &&
              selectedName != null &&
              selectedName.isNotEmpty &&
              index == -1
          ? selectedName
          : null;
      _loading = false;
    });
  }

  Future<void> _onBuildTap(int index, GameBuild gameBuild) async {
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
      setState(() {
        selectedBuild = index;
      });
      gamesNotifier.setSelectedBuild(gameId, gameBuild.versionName);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _SwitchBuildDialog(versionName: gameBuild.versionName),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      selectedBuild = index;
    });
    gamesNotifier.setSelectedBuild(gameId, gameBuild.versionName);

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
        const SnackBar(
          content: Text(
            "Switching build — check the Downloads tab for progress",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
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
                    _RefreshChip(onTap: _loadBuilds),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (_staleBuildName != null) ...[
                  Text(
                    'Installed build "$_staleBuildName" is no longer listed '
                    'by GOG. Select the build to switch to — Lumen will '
                    'repair the install against it.',
                    style: AppText.meta(color: AppColors.error),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (_loading)
                  const CenteredLoader()
                else if (_builds == null)
                  _BuildsMessage(
                    message: "Couldn't load builds.",
                    onRetry: _loadBuilds,
                  )
                else if (_builds!.isEmpty)
                  _BuildsMessage(
                    message: 'No builds available.',
                    onRetry: _loadBuilds,
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _builds!.length,
                    itemBuilder: (context, index) => _BuildListItem(
                      isSelected: index == selectedBuild,
                      gameBuild: _builds![index],
                      onTap: (gameBuild) => _onBuildTap(index, gameBuild),
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
  const _SwitchBuildDialog({required this.versionName});

  final String versionName;

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
              Text('Switch to $versionName?', style: AppText.sectionLabel),
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
                    icon: Icons.sync,
                    label: 'Switch',
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

/// Message with a Retry action, for when the builds fetch failed or came
/// back empty.
class _BuildsMessage extends StatelessWidget {
  const _BuildsMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: AppDecorations.glassRow(),
    child: Column(
      spacing: AppSpacing.md,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppText.bodyMedium(color: AppColors.text70),
        ),
        PrimaryButton(
          onTap: onRetry,
          child: Text('Retry', style: AppText.button(color: Colors.white)),
        ),
      ],
    ),
  );
}

/// Quiet "↻ Refresh" chip re-fetching the build list.
class _RefreshChip extends StatelessWidget {
  const _RefreshChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClickableContainer(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.fill06,
          border: Border.all(color: AppColors.border10),
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            const Icon(Icons.refresh, size: 14, color: AppColors.text80),
            Text(
              'Refresh',
              style: AppText.onest(
                size: 12.5,
                weight: FontWeight.w600,
                color: AppColors.text80,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildListItem extends StatelessWidget {
  const _BuildListItem({
    required this.gameBuild,
    required this.onTap,
    required this.isSelected,
  });

  final GameBuild gameBuild;
  final Function(GameBuild) onTap;
  final bool isSelected;

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
                    Text(gameBuild.versionName, style: AppText.cardTitle()),
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
                        'Switch',
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
