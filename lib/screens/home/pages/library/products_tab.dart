import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/clickable_container.dart';
import 'package:lumen/components/centered_loader.dart';
import 'package:lumen/components/panel.dart';
import 'package:lumen/components/retry_message.dart';
import 'package:lumen/models/downloadable_product.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/library_state.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

class ProductsTab extends ConsumerStatefulWidget {
  const ProductsTab({super.key, required this.gameId});

  final int gameId;

  @override
  ConsumerState<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends ConsumerState<ProductsTab> {
  @override
  void initState() {
    super.initState();
    // Registered after the first frame so the GamesNotifier mutation never
    // runs during build. Fires once with the cached products and again only
    // when they're refetched.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final String? buildName = ref
          .read(gamesStateProvider)
          .getSelectedBuild(widget.gameId);
      if (buildName == null) return;
      ref.listenManual(
        gameProductsProvider((gameId: widget.gameId, buildName: buildName)),
        (_, next) {
          final gamesNotifier = ref.read(gamesStateProvider.notifier);
          for (final product in next.value ?? const <DownloadableProduct>[]) {
            if (product.productType == "GAME") {
              gamesNotifier.addProductId(widget.gameId, product.id);
            }
          }
        },
        fireImmediately: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final GamesState gamesState = ref.watch(gamesStateProvider);
    final String? buildName = gamesState.getSelectedBuild(widget.gameId);
    final key = buildName == null
        ? null
        : (gameId: widget.gameId, buildName: buildName);
    final productsAsync = key == null
        ? null
        : ref.watch(gameProductsProvider(key));
    final dlcProducts = productsAsync?.value
        ?.where((product) => product.productType != "GAME")
        .toList();
    final Set<int> selectedProductIds = gamesState.getProductIds(widget.gameId);
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
                if (productsAsync != null &&
                    !productsAsync.isLoading &&
                    dlcProducts == null)
                  RetryMessage(
                    message: "Couldn't load products.",
                    onRetry: () => ref.invalidate(gameProductsProvider(key!)),
                  )
                else if (dlcProducts != null)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: dlcProducts.length,
                    itemBuilder: (context, index) {
                      final product = dlcProducts[index];
                      return _BuildListItem(
                        product: product,
                        isSelected: selectedProductIds.contains(product.id),
                        onTap: (product) => ref
                            .read(gamesStateProvider.notifier)
                            .toggleProductId(widget.gameId, product.id),
                      );
                    },
                  )
                else
                  const CenteredLoader(),
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
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Panel(
          selected: isSelected,
          child: Row(
            spacing: AppSpacing.md,
            children: [
              Expanded(
                child: Column(
                  spacing: 3,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: AppText.cardTitle()),
                    Text(product.productType, style: AppText.cardDesc()),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 18,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
