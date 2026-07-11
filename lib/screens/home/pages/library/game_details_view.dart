import 'package:flutter/material.dart';
import 'package:gogdl2_flutter/components/primary_button.dart';
import 'package:gogdl2_flutter/components/tab_button.dart';
import 'package:gogdl2_flutter/screens/home/pages/library/builds_tab.dart';
import 'package:gogdl2_flutter/screens/home/pages/library/game_header.dart';
import 'package:gogdl2_flutter/screens/home/pages/library/game_settings_tab.dart';
import 'package:gogdl2_flutter/screens/home/pages/library/overview_tab.dart';
import 'package:gogdl2_flutter/screens/home/pages/library/products_tab.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';
import 'package:gogdl2_flutter/theme/app_dimens.dart';

enum SelectedTab { overview, builds, settings, dlc }

extension SelectedTabLabel on SelectedTab {
  String get label => switch (this) {
    SelectedTab.overview => 'Overview',
    SelectedTab.builds => 'Builds',
    SelectedTab.dlc => 'DLC',
    SelectedTab.settings => 'Settings',
  };
}

/// Detail view for one game: back button, header banner and the info tabs.
class GameDetailsView extends StatelessWidget {
  const GameDetailsView({
    super.key,
    required this.gameId,
    required this.goBack,
  });

  final int gameId;
  final VoidCallback goBack;

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size.width * 0.05,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PrimaryButton.icon(
                onTap: goBack,
                icon: Icons.arrow_back,
                label: 'Library',
                foreground: AppColors.textSecondary,
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          GameHeader(gameId: gameId),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: _GameTabs(gameId: gameId)),
        ],
      ),
    );
  }
}

class _GameTabs extends StatefulWidget {
  const _GameTabs({required this.gameId});

  final int gameId;

  @override
  State<_GameTabs> createState() => _GameTabsState();
}

class _GameTabsState extends State<_GameTabs> {
  SelectedTab _selectedTab = SelectedTab.overview;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border12)),
          ),
          child: Row(
            children: [
              for (final tab in SelectedTab.values)
                TabButton(
                  label: tab.label,
                  style: TabButtonStyle.underline,
                  isSelected: _selectedTab == tab,
                  onTap: () {
                    setState(() {
                      _selectedTab = tab;
                    });
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: switch (_selectedTab) {
            SelectedTab.overview => OverviewTab(gameId: widget.gameId),
            SelectedTab.builds => BuildsTab(gameId: widget.gameId),
            SelectedTab.settings => GameSettingsTab(gameId: widget.gameId),
            SelectedTab.dlc => ProductsTab(gameId: widget.gameId),
          },
        ),
      ],
    );
  }
}
