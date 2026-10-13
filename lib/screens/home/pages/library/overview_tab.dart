import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/components/async_cover_image.dart';
import 'package:lumen/components/centered_loader.dart';
import 'package:lumen/components/section_card.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/library_state.dart';
import 'package:lumen/state/proton_state.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

/// Game summary, screenshots grid and the details side panel.
class OverviewTab extends ConsumerWidget {
  const OverviewTab({super.key, required this.gameId});

  final int gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: SingleChildScrollView(child: _summaryColumn(ref))),
        const SizedBox(width: AppSpacing.lg),
        SizedBox(
          width: _getTabWidth(size.width),
          child: _detailsColumn(ref, size),
        ),
      ],
    );
  }

  Widget _summaryColumn(WidgetRef ref) {
    final String? summary = ref.watch(gameSummaryProvider(gameId)).value;
    final List<String> screenshots =
        ref.watch(gameScreenshotsProvider(gameId)).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        (summary == null)
            ? const CenteredLoader()
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Text(summary, style: AppText.bodyLong),
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
          itemCount: screenshots.length,
          itemBuilder: (context, index) => AsyncCoverImage.resolved(
            screenshots[index],
            decodeAtLayoutWidth: true,
            borderRadius: AppRadii.buttonLarge,
          ),
        ),
      ],
    );
  }

  Widget _detailsColumn(WidgetRef ref, Size size) {
    if (_getTabWidth(size.width) <= 0) {
      return const SizedBox.shrink();
    }

    final gamesState = ref.watch(gamesStateProvider);
    final protonState = ref.watch(protonStateProvider);

    final GameStatus gameStatus = gamesState.getGameStatus(gameId);
    final String statusLabel = switch (gameStatus) {
      GameStatus.downloading => 'Installing',
      GameStatus.paused => 'Paused',
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
    final double tabWidth = width > 1080
        ? pow(width * 0.05, 1.3).toDouble()
        : 0;
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
