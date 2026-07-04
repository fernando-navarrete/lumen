import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl2_flutter/components/game_card.dart';
import 'package:gogdl2_flutter/state/gog_state.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var gogState = ref.watch(gogStateProvider);
    return Expanded(
      child: Column(
        children: [
          SizedBox(height: 24),
          _Library(gogState: gogState),
        ],
      ),
    );
  }
}

class _Library extends StatelessWidget {
  final GogState gogState;

  const _Library({required this.gogState});

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: size.width * 0.05),
        child: FutureBuilder<List<int>?>(
          future: gogState.getOwnedGames(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: size.width ~/ 200,
                  childAspectRatio: 9 / 12,
                  mainAxisSpacing: (size.width * 0.015).clamp(0.0, 15.0),
                  crossAxisSpacing: (size.width * 0.015).clamp(0.0, 15.0),
                ),
                itemBuilder: (context, index) {
                  return FutureBuilder<String?>(
                    future: gogState.getGameName(snapshot.data![index]),
                    builder: (context, nameSnapshot) {
                      if (nameSnapshot.hasData) {
                        String? title = nameSnapshot.data ?? '';
                        int? gameId = snapshot.data?[index];
                        if (title.isEmpty || gameId == null) {
                          return const SizedBox.shrink();
                        }
                        return GameCard(gameId: gameId, gameName: title);
                      } else {
                        return const CircularProgressIndicator();
                      }
                    },
                  );
                },
                itemCount: snapshot.data?.length,
              );
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }
}
