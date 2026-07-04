import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl2_flutter/components/async_cover_image.dart';
import 'package:gogdl2_flutter/components/gradient_background.dart';
import 'package:gogdl2_flutter/state/gog_state.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';
import 'package:gogdl2_flutter/theme/app_decorations.dart';
import 'package:gogdl2_flutter/theme/text_styles.dart';

class GameScreen extends ConsumerStatefulWidget {
  final int? gameId;

  const GameScreen({super.key, this.gameId});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return _GameScreenState();
  }
}

class _GameScreenState extends ConsumerState<GameScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: Column(
          children: [
            //const NavBar(),
            const _BackButton(),
            _GameHeader(gameId: widget.gameId),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        Navigator.pop(context);
      },
    );
  }
}

class _GameHeader extends ConsumerWidget {
  final int? gameId;

  const _GameHeader({this.gameId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var size = MediaQuery.of(context).size;
    var gogState = ref.watch(gogStateProvider);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size.width * 0.05,
        vertical: 24,
      ),
      child: Container(
        height: 316,
        decoration: AppDecorations.card(
          borderRadius: 13.0,
          borderColor: AppColors.border12,
          blurRadius: 18,
          spreadRadius: 8,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AsyncCoverImage(
                imageUrl: gogState.getGameBackgroundLink(gameId!),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              bottom: 0,
              child: Container(
                width: size.width * 2 / 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13.0),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withAlpha(210),
                      Colors.black.withAlpha(175),
                      Colors.black.withAlpha(140),
                      Colors.black.withAlpha(105),
                      Colors.black.withAlpha(70),
                      Colors.black.withAlpha(35),
                      Colors.black.withAlpha(0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 28, vertical: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FutureBuilder<String?>(
                      future: gogState.getGameName(gameId!),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? 'Loading...',
                          style: AppText.onest(
                            color: Colors.white,
                            size: 44,
                            weight: FontWeight.w800,
                          ),
                        );
                      },
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
}
