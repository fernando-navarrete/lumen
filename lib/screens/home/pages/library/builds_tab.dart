import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl2_flutter/common/clickable_container.dart';
import 'package:gogdl2_flutter/components/centered_loader.dart';
import 'package:gogdl2_flutter/components/panel.dart';
import 'package:gogdl2_flutter/state/games_state.dart';
import 'package:gogdl2_flutter/state/gog_state.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';
import 'package:gogdl2_flutter/theme/app_dimens.dart';
import 'package:gogdl2_flutter/theme/text_styles.dart';
import 'package:gogdl2_flutter_bridge/gogdl2_flutter_bridge.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    GamesState gamesState = ref.read(gamesStateProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select which build to install. Switching re-downloads the changed files.',
                  style: AppText.caption(color: AppColors.textSecondary),
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
                            gamesState.setSelectedBuild(
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
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Panel(
          selected: isSelected,
          child: Column(
            spacing: AppSpacing.xs,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gameBuild.versionName,
                style: AppText.bodyMedium(
                  color: Colors.white,
                  weight: FontWeight.w600,
                ),
              ),
              Text(
                releaseDate,
                style: AppText.caption(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
