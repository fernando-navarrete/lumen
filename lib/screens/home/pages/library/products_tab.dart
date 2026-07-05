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

class ProductsTab extends ConsumerStatefulWidget {
  const ProductsTab({super.key, required this.gameId});

  final int gameId;

  @override
  ConsumerState<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends ConsumerState<ProductsTab> {
  List<DownloadableProduct>? _products;
  Set<String> _selectedProductIds = {};

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      GogState gogState = ref.read(gogStateProvider);
      GamesState gamesState = ref.read(gamesStateProvider);
      String? selectedVersionName = gamesState.getSelectedBuild(widget.gameId);

      if (selectedVersionName != null) {
        _products = await gogState.getProducts(
          widget.gameId,
          selectedVersionName,
        );
        for (final product in _products ?? const <DownloadableProduct>[]) {
          if (product.productType == "GAME") {
            gamesState.addProductId(widget.gameId, product.id);
          }
        }
      }

      _selectedProductIds = gamesState.getProductIds(widget.gameId);
      setState(() {});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    GamesState gamesState = ref.read(gamesStateProvider);
    final dlcProducts = _products
        ?.where((product) => product.productType != "GAME")
        .toList();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select all products to download',
                  style: AppText.caption(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                (_products != null)
                    ? ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: dlcProducts!.length,
                        itemBuilder: (context, index) {
                          final product = dlcProducts[index];
                          return Column(
                            children: [
                              _BuildListItem(
                                product: product,
                                isSelected: _selectedProductIds.contains(
                                  product.id,
                                ),
                                onTap: (product) {
                                  setState(() {
                                    if (!_selectedProductIds.remove(
                                      product.id,
                                    )) {
                                      _selectedProductIds.add(product.id);
                                    }
                                  });
                                  gamesState.toggleProductId(
                                    widget.gameId,
                                    product.id,
                                  );
                                },
                              ),
                            ],
                          );
                        },
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
    required this.product,
    required this.onTap,
    required this.isSelected,
  });

  final DownloadableProduct product;
  final Function(DownloadableProduct) onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return ClickableContainer(
      onTap: () => onTap(product),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Panel(
          selected: isSelected,
          child: Column(
            spacing: AppSpacing.xs,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: AppText.bodyMedium(
                  color: Colors.white,
                  weight: FontWeight.w600,
                ),
              ),
              Text(
                product.productType,
                style: AppText.caption(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
