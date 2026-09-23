import 'package:flutter/material.dart';
import 'package:lumen/common/clickable_container.dart';
import 'package:lumen/components/tab_button.dart';
import 'package:lumen/screens/home/pages/library/builds_tab.dart';
import 'package:lumen/screens/home/pages/library/game_header.dart';
import 'package:lumen/screens/home/pages/library/game_settings_tab.dart';
import 'package:lumen/screens/home/pages/library/overview_tab.dart';
import 'package:lumen/screens/home/pages/library/products_tab.dart';
import 'package:lumen/screens/home/pages/library/saves_tab.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

enum SelectedTab { overview, builds, settings, dlc, saves }

extension SelectedTabLabel on SelectedTab {
  String get label => switch (this) {
    SelectedTab.overview => 'Overview',
    SelectedTab.builds => 'Builds',
    SelectedTab.dlc => 'DLC',
    SelectedTab.saves => 'Saves',
    SelectedTab.settings => 'Settings',
  };
}

/// Detail view for one game: back button, header banner and the info tabs.
class GameDetailsView extends StatefulWidget {
  const GameDetailsView({
    super.key,
    required this.gameId,
    required this.goBack,
  });

  final int gameId;
  final VoidCallback goBack;

  @override
  State<GameDetailsView> createState() => _GameDetailsViewState();
}

class _GameDetailsViewState extends State<GameDetailsView> {
  SelectedTab _selectedTab = SelectedTab.overview;

  @override
  void didUpdateWidget(covariant GameDetailsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gameId != widget.gameId) {
      _selectedTab = SelectedTab.overview;
    }
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size.width * 0.05,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _BackPill(onTap: widget.goBack),
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GameHeader(
            gameId: widget.gameId,
            onConfigure: () {
              setState(() {
                _selectedTab = SelectedTab.settings;
              });
            },
            onSelectBuild: () {
              setState(() {
                _selectedTab = SelectedTab.builds;
              });
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: _GameTabs(
              gameId: widget.gameId,
              selectedTab: _selectedTab,
              onTabSelected: (tab) {
                setState(() {
                  _selectedTab = tab;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Quiet glass "← Library" pill returning to the grid.
class _BackPill extends StatelessWidget {
  const _BackPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClickableContainer(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
        decoration: BoxDecoration(
          color: AppColors.fill05,
          border: Border.all(color: AppColors.border08),
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.xs,
          children: [
            const Icon(
              Icons.arrow_back,
              size: 15,
              color: AppColors.textSecondary,
            ),
            Text(
              'Library',
              style: AppText.onest(
                size: 13,
                weight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameTabs extends StatelessWidget {
  const _GameTabs({
    required this.gameId,
    required this.selectedTab,
    required this.onTabSelected,
  });

  final int gameId;
  final SelectedTab selectedTab;
  final ValueChanged<SelectedTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border08)),
          ),
          child: Row(
            children: [
              for (final tab in SelectedTab.values)
                TabButton(
                  label: tab.label,
                  style: TabButtonStyle.underline,
                  isSelected: selectedTab == tab,
                  onTap: () => onTabSelected(tab),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: switch (selectedTab) {
            SelectedTab.overview => OverviewTab(gameId: gameId),
            SelectedTab.builds => BuildsTab(gameId: gameId),
            SelectedTab.settings => GameSettingsTab(gameId: gameId),
            SelectedTab.dlc => ProductsTab(gameId: gameId),
            SelectedTab.saves => SavesTab(gameId: gameId),
          },
        ),
      ],
    );
  }
}
