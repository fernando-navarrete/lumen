import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/components/centered_loader.dart';
import 'package:lumen/components/chip_button.dart';
import 'package:lumen/components/game_action_buttons.dart';
import 'package:lumen/components/game_card.dart';
import 'package:lumen/components/hero_banner.dart';
import 'package:lumen/components/primary_button.dart';
import 'package:lumen/components/refresh_chip.dart';
import 'package:lumen/screens/home/pages/library/game_details_view.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/state/home_state.dart';
import 'package:lumen/state/library_state.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_decorations.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

/// Switches between the owned-games grid and the details of the game held
/// by [librarySelectionProvider].
class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(librarySelectionProvider);
    final notifier = ref.read(librarySelectionProvider.notifier);
    return selection == null
        ? _GameGrid(onGameTap: notifier.select)
        : GameDetailsView(gameId: selection.gameId, goBack: notifier.clear);
  }
}

enum _LibraryFilter { all, installed, notInstalled }

extension _LibraryFilterLabel on _LibraryFilter {
  String get label => switch (this) {
    _LibraryFilter.all => 'All',
    _LibraryFilter.installed => 'Installed',
    _LibraryFilter.notInstalled => 'Not installed',
  };

  bool matches(GameStatus status) => switch (this) {
    _LibraryFilter.all => true,
    _LibraryFilter.installed =>
      status == GameStatus.downloaded ||
          status == GameStatus.downloading ||
          status == GameStatus.paused,
    _LibraryFilter.notInstalled => status == GameStatus.notInstalled,
  };
}

class _GameGrid extends ConsumerStatefulWidget {
  const _GameGrid({required this.onGameTap});

  final ValueChanged<int> onGameTap;

  @override
  _GameGridState createState() => _GameGridState();
}

class _GameGridState extends ConsumerState<_GameGrid> {
  _LibraryFilter _filter = _LibraryFilter.all;

  Future<void> _refresh() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(libraryRefresherProvider).refresh();
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't refresh your library.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final owned = ref.watch(ownedGamesProvider);
    void retry() => ref.invalidate(ownedGamesProvider);
    // An invalidate keeps the previous value, so a refresh doesn't land here.
    if (owned.isLoading && !owned.hasValue) {
      return const CenteredLoader();
    }
    final List<int>? ownedGames = owned.value;
    if (ownedGames == null) {
      return _LibraryMessage(
        message: "Couldn't load your library.",
        onRetry: retry,
      );
    }
    if (ownedGames.isEmpty) {
      return _LibraryMessage(
        message: 'No games in your library.',
        onRetry: retry,
      );
    }

    // A game whose title hasn't loaded (or failed) is '' here.
    final List<String> gameNames = [
      for (final id in ownedGames) ref.watch(gameTitleProvider(id)).value ?? '',
    ];

    final gogState = ref.watch(gogStateProvider);
    final gamesState = ref.watch(gamesStateProvider);
    final String query = ref.watch(librarySearchProvider).trim().toLowerCase();

    // Indices surviving the search field and the status filter chips.
    final List<int> visible = [
      for (int i = 0; i < ownedGames.length; i++)
        if (_filter.matches(gamesState.getGameStatus(ownedGames[i])) &&
            (query.isEmpty || gameNames[i].toLowerCase().contains(query)))
          i,
    ];

    // Featured game: first installed one, else the first in the library.
    final int featuredIndex = ownedGames.indexWhere(
      (id) => gamesState.getGameStatus(id) == GameStatus.downloaded,
    );
    final int featuredId = ownedGames[featuredIndex < 0 ? 0 : featuredIndex];
    final String featuredName =
        gameNames[featuredIndex < 0 ? 0 : featuredIndex];
    final bool featuredInstalled = featuredIndex >= 0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1500),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
              sliver: SliverToBoxAdapter(
                child: HeroBanner(
                  imageUrl: gogState.getGameBackgroundLink(featuredId),
                  eyebrow: featuredInstalled ? 'CONTINUE PLAYING' : 'FEATURED',
                  title: featuredName,
                  metaChildren: [
                    Text(
                      featuredInstalled ? '● Installed' : '↓ Not installed',
                      style: AppText.meta(
                        color: featuredInstalled
                            ? AppColors.primary
                            : AppColors.text70,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                  actions: [
                    GameActionButtons(gameId: featuredId, large: true),
                    PrimaryButton(
                      onTap: () => widget.onGameTap(featuredId),
                      large: true,
                      child: Text(
                        'Details',
                        style: AppText.button(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(26, 26, 26, AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: Row(
                  spacing: AppSpacing.sm,
                  children: [
                    Text('Your library', style: AppText.sectionTitle),
                    const SizedBox(width: 2),
                    for (final filter in _LibraryFilter.values)
                      ChipButton(
                        label: filter.label,
                        selected: _filter == filter,
                        onTap: () {
                          setState(() {
                            _filter = filter;
                          });
                        },
                      ),
                    const Spacer(),
                    Text(
                      '${visible.length} games',
                      style: AppText.onest(
                        size: 12.5,
                        weight: FontWeight.w400,
                        color: AppColors.text40,
                      ),
                    ),
                    RefreshChip(busy: owned.isLoading, onTap: _refresh),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  childAspectRatio: 3 / 4,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final int i = visible[index];
                  if (gameNames[i].isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return GameCard(
                    gameId: ownedGames[i],
                    gameName: gameNames[i],
                    onTap: () {
                      widget.onGameTap(ownedGames[i]);
                    },
                  );
                }, childCount: visible.length),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centered message with a Retry action, for when the owned-games fetch
/// failed or came back empty.
class _LibraryMessage extends StatelessWidget {
  const _LibraryMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: AppDecorations.glassRow(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.md,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.bodyMedium(color: AppColors.text70),
            ),
            PrimaryButton(
              onTap: onRetry,
              child: Text('Retry', style: AppText.button(color: Colors.white)),
            ),
          ],
        ),
      ),
    ),
  );
}
