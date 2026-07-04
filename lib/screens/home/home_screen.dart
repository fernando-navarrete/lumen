import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl2_flutter/components/async_cover_image.dart';
import 'package:gogdl2_flutter/components/bounce_marquee.dart';
import 'package:gogdl2_flutter/components/gradient_background.dart';
import 'package:gogdl2_flutter/components/nav_bar.dart';
import 'package:gogdl2_flutter/screens/game/game_screen.dart';
import 'package:gogdl2_flutter/state/gog_state.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';
import 'package:gogdl2_flutter/theme/app_decorations.dart';
import 'package:gogdl2_flutter/theme/text_styles.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: Column(
          children: [const NavBar(), const _LibraryFilter(), const _Library()],
        ),
      ),
    );
  }
}

class _LibraryFilter extends StatelessWidget {
  const _LibraryFilter();

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size.width * 0.05,
        vertical: 24,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Your library",
            style: AppText.onest(
              size: 18,
              color: Colors.white,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Library extends ConsumerWidget {
  const _Library();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var size = MediaQuery.of(context).size;
    var gogState = ref.watch(gogStateProvider);

    var ownedGames = gogState.getOwnedGames();
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: size.width * 0.05),
        child: FutureBuilder<List<int>?>(
          future: ownedGames,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: size.width ~/ 200,
                  childAspectRatio: 9 / 12,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
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
                        return _GameCard(
                          gameId: gameId,
                          gameName: title,
                          gogState: gogState,
                        );
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

class _GameCard extends StatelessWidget {
  final int? gameId;
  final String gameName;
  final GogState gogState;

  const _GameCard({
    this.gameId,
    required this.gameName,
    required this.gogState,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (gameId != null) {
          _onGameTap(context, gameId!);
        }
      },
      child: Container(
        decoration: AppDecorations.card(
          borderRadius: 13.0,
          borderColor: AppColors.border12,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AsyncCoverImage(
                imageUrl: gogState.getGameBoxartLink(gameId!),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 56,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(0),
                      Colors.black.withAlpha(196),
                      Colors.black.withAlpha(255),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoMarqueeText(
                      text: gameName,
                      style: TextStyle(color: Colors.white),
                    ),
                    Text(
                      "Not installed",
                      style: AppText.onest(
                        size: 12,
                        color: Colors.grey,
                        weight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onGameTap(BuildContext context, int gameId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GameScreen(gameId: gameId)),
    );
  }
}
