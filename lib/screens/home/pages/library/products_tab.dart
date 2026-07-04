import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl2_flutter/components/centered_loader.dart';
import 'package:gogdl2_flutter/components/panel.dart';
import 'package:gogdl2_flutter/state/gog_state.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';
import 'package:gogdl2_flutter/theme/app_dimens.dart';
import 'package:gogdl2_flutter/theme/text_styles.dart';
import 'package:gogdl2_flutter_bridge/gogdl2_flutter_bridge.dart';

/// List of the game's available builds.
class ProductsTab extends ConsumerStatefulWidget {
  const ProductsTab({super.key, required this.gameId});

  final int gameId;

  @override
  ConsumerState<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends ConsumerState<ProductsTab> {
  List<GameBuild>? _builds;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      GogState gogState = ref.read(gogStateProvider);
      _builds = await gogState.getBuilds(widget.gameId);
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
                        itemBuilder: (context, index) =>
                            _BuildListItem(gameBuild: _builds![index]),
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
  const _BuildListItem({required this.gameBuild});

  final GameBuild gameBuild;

  @override
  Widget build(BuildContext context) {
    final releaseDate = gameBuild.releaseDate.replaceAll(RegExp(r'\+0000'), '');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Panel(
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
    );
  }
}
