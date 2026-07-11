import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/components/async_cover_image.dart';
import 'package:lumen/components/centered_loader.dart';
import 'package:lumen/components/panel.dart';
import 'package:lumen/state/gog_state.dart';
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
          : Text(
              _gameSummary!,
              style: AppText.bodyMedium(color: AppColors.textSecondary),
            ),
      const SizedBox(height: AppSpacing.xl),
      Text("MEDIA", style: AppText.sectionLabel),
      const SizedBox(height: AppSpacing.xs),
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
        itemBuilder: (context, index) =>
            AsyncCoverImage.resolved(_screenshots[index], fit: BoxFit.fill),
      ),
    ],
  );

  Widget _detailsColumn(Size size) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      (_getTabWidth(size.width) > 0)
          ? Text("DETAILS", style: AppText.sectionLabel)
          : const SizedBox.shrink(),
      const SizedBox(height: AppSpacing.xs),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Status",
                  style: AppText.bodyMedium(color: AppColors.textSecondary),
                ),
                Text(
                  "Not installed",
                  style: AppText.bodyMedium(color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  double _getTabWidth(double width) {
    double tabWidth = width > 1080 ? pow(width * 0.05, 1.3).toDouble() : 0;
    return tabWidth;
  }
}
