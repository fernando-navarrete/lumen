import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/clickable_container.dart';
import 'package:lumen/common/format.dart';
import 'package:lumen/common/gog_error.dart';
import 'package:lumen/components/centered_loader.dart';
import 'package:lumen/components/panel.dart';
import 'package:lumen/components/primary_button.dart';
import 'package:lumen/components/retry_message.dart';
import 'package:lumen/components/side_column_layout.dart';
import 'package:lumen/models/downloadable_product.dart';
import 'package:lumen/state/downloads_state.dart';
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

  /// The installed game's unapplied DLC selection; null when there are no
  /// changes. Never used for a game that isn't installed, whose toggles write
  /// the config directly.
  Set<int>? _pending;
  bool _applying = false;

  void _setSelection(GamesState games, Set<int> selection) {
    final notifier = ref.read(gamesStateProvider.notifier);
    if (games.getGameStatus(widget.gameId) != GameStatus.downloaded) {
      notifier.setProductIds(widget.gameId, selection);
      return;
    }
    final current = games.getProductIds(widget.gameId);
    setState(
      () => _pending =
          selection.length == current.length && selection.containsAll(current)
          ? null
          : selection,
    );
  }

  Future<void> _apply(Set<int> base) async {
    final pending = _pending;
    if (pending == null) return;
    final current = ref.read(gamesStateProvider).getProductIds(widget.gameId);
    final removing = current.difference(pending).length;
    if (removing > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Remove $removing DLC?', style: AppText.sectionLabel),
          content: Text(
            'Their files are deleted from the install folder.',
            style: AppText.meta(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _applying = true);
    String message;
    try {
      final removal = await ref
          .read(downloadsStateProvider.notifier)
          .applyProductChanges(
            widget.gameId,
            productIds: pending,
            baseProductIds: base,
          );
      final adding = pending.difference(current).isNotEmpty;
      message = adding
          ? 'Installing DLC — check the Downloads tab for progress'
          : 'Removed ${removal?.filesRemoved ?? 0} files '
                '(${formatBytes(removal?.bytesFreed ?? 0)} freed)';
      if (mounted) setState(() => _pending = null);
    } on ProductChangeError catch (e) {
      message = e.message;
    } catch (e) {
      message = jobErrorText(e);
    }
    if (!mounted) return;
    setState(() => _applying = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final GamesState gamesState = ref.watch(gamesStateProvider);
    final String? buildName = gamesState.getSelectedBuild(widget.gameId);
    final key = buildName == null
        ? null
        : (gameId: widget.gameId, buildName: buildName);
    final productsAsync = key == null
        ? null
        : ref.watch(gameProductsProvider(key));
    final allProducts = productsAsync?.value;
    final dlcProducts = allProducts
        ?.where((product) => product.productType != "GAME")
        .toList();
    final Set<int> baseIds = {
      for (final product in allProducts ?? const <DownloadableProduct>[])
        if (product.productType == "GAME") product.id,
    };
    final GameStatus status = gamesState.getGameStatus(widget.gameId);
    final bool installed = status == GameStatus.downloaded;
    final bool locked =
        status == GameStatus.downloading || status == GameStatus.paused;
    final Set<int> configIds = gamesState.getProductIds(widget.gameId);
    final Set<int> selectedProductIds = installed
        ? (_pending ?? configIds)
        : configIds;
    final int installCount = _pending?.difference(configIds).length ?? 0;
    final int removeCount = _pending == null
        ? 0
        : configIds.difference(_pending!).length;
    final bool interactive = !locked && !_applying;
    final dlcIds = {
      for (final p in dlcProducts ?? const <DownloadableProduct>[]) p.id,
    };
    return SideColumnLayout(
      main: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    locked
                        ? 'Finish or cancel the download to change DLC'
                        : installed
                        ? 'Choose DLC to install or remove, then apply'
                        : 'Choose which DLC to install with the game',
                    style: AppText.caption(color: AppColors.textSecondary),
                  ),
                ),
                if (interactive && dlcIds.isNotEmpty) ...[
                  TextButton(
                    onPressed: () => _setSelection(gamesState, {
                      ...selectedProductIds,
                      ...dlcIds,
                    }),
                    child: const Text('Select all'),
                  ),
                  TextButton(
                    onPressed: () => _setSelection(
                      gamesState,
                      selectedProductIds.difference(dlcIds),
                    ),
                    child: const Text('Select none'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (productsAsync != null &&
                !productsAsync.isLoading &&
                dlcProducts == null)
              RetryMessage(
                message: "Couldn't load products.",
                onRetry: () => ref.invalidate(gameProductsProvider(key!)),
              )
            else if (dlcProducts != null && dlcProducts.isEmpty)
              Text(
                'This game has no DLC',
                style: AppText.meta(color: AppColors.textSecondary),
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
                    onTap: (product) {
                      if (!interactive) return;
                      final next = {...selectedProductIds};
                      if (!next.remove(product.id)) next.add(product.id);
                      _setSelection(gamesState, next);
                    },
                  );
                },
              )
            else
              const CenteredLoader(),
            if (installed && _pending != null) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                spacing: AppSpacing.sm,
                children: [
                  Expanded(
                    child: Text(
                      [
                        if (installCount > 0) 'Install $installCount DLC',
                        if (removeCount > 0) 'Remove $removeCount DLC',
                      ].join(' · '),
                      style: AppText.meta(color: AppColors.primaryLight),
                    ),
                  ),
                  TextButton(
                    onPressed: _applying
                        ? null
                        : () => setState(() => _pending = null),
                    child: const Text('Discard'),
                  ),
                  PrimaryButton.icon(
                    icon: Icons.check,
                    label: _applying ? 'Applying…' : 'Apply changes',
                    enabled: !_applying,
                    glowing: true,
                    onTap: () => _apply(baseIds),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: ClickableContainer(
        onTap: () => onTap(product),
        focusRadius: AppRadii.card,
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
