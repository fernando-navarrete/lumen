import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/components/async_cover_image.dart';
import 'package:lumen/components/centered_loader.dart';
import 'package:lumen/components/section_card.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/state/proton_state.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

/// Game summary, screenshots grid and the details side panel.
class OverviewTab extends ConsumerStatefulWidget {
  const OverviewTab({super.key, required this.gameId});

  final int gameId;

  @override
  ConsumerState<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<OverviewTab> {
  String? _gameSummary;
  List<String> _screenshots = [];

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      GogState gogState = ref.read(gogStateProvider);
      _gameSummary = await gogState.getGameSummary(widget.gameId);
      setState(() {});
      _screenshots = await gogState.getGameScreenshots(widget.gameId);
      setState(() {});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: SingleChildScrollView(child: _summaryColumn())),
        const SizedBox(width: AppSpacing.lg),
        SizedBox(
          width: _getTabWidth(size.width),
          child: _detailsColumn(size),
        ),
      ],
    );
  }

  Widget _summaryColumn() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      (_gameSummary == null)
          ? const CenteredLoader()
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Text(_gameSummary!, style: AppText.bodyLong),
            ),
      const SizedBox(height: AppSpacing.lg),
      Text("MEDIA", style: AppText.microLabel),
      const SizedBox(height: AppSpacing.sm),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 16 / 9,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
        ),
        itemCount: _screenshots.length,
        itemBuilder: (context, index) => AsyncCoverImage.resolved(
          _screenshots[index],
          fit: BoxFit.fill,
          borderRadius: AppRadii.buttonLarge,
        ),
      ),
    ],
  );

  Widget _detailsColumn(Size size) {
    if (_getTabWidth(size.width) <= 0) {
      return const SizedBox.shrink();
    }

    final gamesState = ref.watch(gamesStateProvider);
    final protonState = ref.watch(protonStateProvider);
    final gameId = widget.gameId;

    final GameStatus gameStatus = gamesState.getGameStatus(gameId);
    final String statusLabel = switch (gameStatus) {
      GameStatus.downloading => 'Installing',
      GameStatus.downloaded => 'Installed',
      GameStatus.notInstalled => 'Not installed',
    };
    final String? buildVersion = gamesState.getSelectedBuild(gameId);
    final String? protonOverride = gamesState.getProtonVersion(gameId);
    final String? compatibility =
        protonOverride ??
        (protonState.defaultVersion != null
            ? 'Default (${protonState.defaultVersion})'
            : null);
    final String? installPath = gamesState.getInstallPath(gameId);

    final facts = <(String, String)>[
      ('Status', statusLabel),
      if (gameStatus == GameStatus.downloaded &&
          buildVersion != null &&
          buildVersion.isNotEmpty)
        ('Installed version', buildVersion),
      if (compatibility != null) ('Compatibility', compatibility),
      if (installPath != null) ('Install path', installPath),
    ];

    return SectionCard.rows(
      child: Column(
        children: [
          for (final (index, fact) in facts.indexed)
            _FactRow(
              label: fact.$1,
              value: fact.$2,
              isLast: index == facts.length - 1,
            ),
        ],
      ),
    );
  }

  double _getTabWidth(double width) {
    double tabWidth = width > 1080 ? pow(width * 0.05, 1.3).toDouble() : 0;
    return tabWidth;
  }
}

/// One key/value line in the facts panel, divided by a hairline.
class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.label,
    required this.value,
    required this.isLast,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.meta(color: AppColors.textSecondary)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              style: AppText.meta(color: Colors.white, weight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
