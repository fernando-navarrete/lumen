import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/clickable_container.dart';
import 'package:lumen/components/centered_loader.dart';
import 'package:lumen/components/panel.dart';
import 'package:lumen/models/game_build.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_state.dart';
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
  List<GameBuild>? _builds;
  int selectedBuild = -1;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBuilds());
    super.initState();
  }

  Future<void> _loadBuilds() async {
    setState(() {
      _builds = null;
    });
    GogState gogState = ref.read(gogStateProvider);
    _builds = await gogState.getBuilds(widget.gameId);
    setState(() {});

    GamesState gamesState = ref.read(gamesStateProvider);
    String? selectedName = gamesState.getSelectedBuild(widget.gameId);
    if (selectedName == null) {
      selectedBuild = -1;
    } else {
      int index = _builds!.indexWhere((b) => b.versionName == selectedName);
      selectedBuild = index;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    GamesNotifier gamesNotifier = ref.read(gamesStateProvider.notifier);
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
                (_builds != null)
                    ? ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _builds!.length,
                        itemBuilder: (context, index) => _BuildListItem(
                          isSelected: index == selectedBuild,
                          gameBuild: _builds![index],
                          onTap: (gameBuild) {
                            setState(() {
                              selectedBuild = index;
                            });
                            gamesNotifier.setSelectedBuild(
                              widget.gameId,
                              gameBuild.versionName,
                            );
                          },
                        ),
                      )
                    : const CenteredLoader(),
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
    double tabWidth = width > 600 ? pow(width * 0.05, 1.5).toDouble() : 0;
    return tabWidth;
  }
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
