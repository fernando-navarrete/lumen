import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/components/centered_loader.dart';
import 'package:lumen/components/game_card.dart';
import 'package:lumen/screens/home/pages/library/game_details_view.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/theme/app_dimens.dart';

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
        ? Column(
            children: [
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: _GameGrid(
                  onGameTap: (gameId) {
                    setState(() {
                      selectedGame = gameId;
                    });
                  },
                ),
              ),
            ],
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

class _GameGrid extends ConsumerStatefulWidget {
  const _GameGrid({required this.onGameTap});

  final ValueChanged<int> onGameTap;

  @override
  _GameGridState createState() => _GameGridState();
}

class _GameGridState extends ConsumerState<_GameGrid> {
  List<int> _ownedGames = [];
  List<String> _gameNames = [];

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      var gogState = ref.read(gogStateProvider);
      _ownedGames = await gogState.getOwnedGames() ?? [];
      _gameNames = List.filled(_ownedGames.length, '');
      setState(() {});
      for (int i = 0; i < _ownedGames.length; i++) {
        final name = await gogState.getGameName(_ownedGames[i]);
        if (name != null) {
          _gameNames[i] = name;
          setState(() {});
        }
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size.width * 0.05),
      child: _ownedGames.isEmpty
          ? const CenteredLoader()
          : GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: size.width ~/ 200,
                childAspectRatio: 9 / 12,
                mainAxisSpacing: (size.width * 0.015).clamp(0.0, 15.0),
                crossAxisSpacing: (size.width * 0.015).clamp(0.0, 15.0),
              ),
              itemCount: _ownedGames.length,
              itemBuilder: (context, index) {
                if (_gameNames[index].isEmpty) {
                  return const SizedBox.shrink();
                }
                return GameCard(
                  gameId: _ownedGames[index],
                  gameName: _gameNames[index],
                  onTap: () {
                    widget.onGameTap(_ownedGames[index]);
                  },
                );
              },
            ),
    );
  }
}
