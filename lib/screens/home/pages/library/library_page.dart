import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/components/centered_loader.dart';
import 'package:lumen/components/chip_button.dart';
import 'package:lumen/components/game_action_buttons.dart';
import 'package:lumen/components/game_card.dart';
import 'package:lumen/components/hero_banner.dart';
import 'package:lumen/components/primary_button.dart';
import 'package:lumen/screens/home/pages/library/game_details_view.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/state/home_state.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_decorations.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

/// Switches between the owned-games grid and the details of a selected game.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  int? selectedGame;

  @override
  Widget build(BuildContext context) {
    return (selectedGame == null)
        ? _GameGrid(
            onGameTap: (gameId) {
              setState(() {
                selectedGame = gameId;
              });
            },
          )
        : GameDetailsView(
            gameId: selectedGame!,
            goBack: () {
              setState(() {
                selectedGame = null;
              });
            },
          );
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
  bool _loading = true;
  List<int>? _ownedGames;
  List<String> _gameNames = [];
  _LibraryFilter _filter = _LibraryFilter.all;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    super.initState();
  }

  Future<void> _load({bool retry = false}) async {
    if (!mounted) return;
    setState(() => _loading = true);
    var gogState = ref.read(gogStateProvider);
    if (retry) {
      gogState.invalidateOwnedGames();
    }
    final owned = await gogState.getOwnedGames();
    if (!mounted) return;
    setState(() {
      _ownedGames = owned;
      _gameNames = List.filled(owned?.length ?? 0, '');
      _loading = false;
    });
    if (owned == null) {
      return;
    }
    for (int i = 0; i < owned.length; i++) {
      final name = await gogState.getGameName(owned[i]);
      if (!mounted) return;
      if (name != null) {
        setState(() => _gameNames[i] = name);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const CenteredLoader();
    }
    if (_ownedGames == null) {
      return _LibraryMessage(
        message: "Couldn't load your library.",
        onRetry: () => _load(retry: true),
      );
    }
    if (_ownedGames!.isEmpty) {
      return _LibraryMessage(
        message: 'No games in your library.',
        onRetry: () => _load(retry: true),
      );
    }
    final List<int> ownedGames = _ownedGames!;

    final gogState = ref.watch(gogStateProvider);
    final gamesState = ref.watch(gamesStateProvider);
    final String query = ref.watch(librarySearchProvider).trim().toLowerCase();

    // Indices surviving the search field and the status filter chips.
    final List<int> visible = [
      for (int i = 0; i < ownedGames.length; i++)
        if (_filter.matches(gamesState.getGameStatus(ownedGames[i])) &&
            (query.isEmpty || _gameNames[i].toLowerCase().contains(query)))
          i,
    ];

    // Featured game: first installed one, else the first in the library.
    final int featuredIndex = ownedGames.indexWhere(
      (id) => gamesState.getGameStatus(id) == GameStatus.downloaded,
    );
    final int featuredId = ownedGames[featuredIndex < 0 ? 0 : featuredIndex];
    final String featuredName =
        _gameNames[featuredIndex < 0 ? 0 : featuredIndex];
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
                  if (_gameNames[i].isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return GameCard(
                    gameId: ownedGames[i],
                    gameName: _gameNames[i],
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
