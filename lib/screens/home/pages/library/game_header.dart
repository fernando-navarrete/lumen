import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl2_flutter/components/async_cover_image.dart';
import 'package:gogdl2_flutter/components/primary_button.dart';
import 'package:gogdl2_flutter/state/gog_state.dart';
import 'package:gogdl2_flutter/theme/app_decorations.dart';
import 'package:gogdl2_flutter/theme/app_dimens.dart';
import 'package:gogdl2_flutter/theme/text_styles.dart';

/// Wide banner with the game's background art and its title over a scrim.
class GameHeader extends ConsumerWidget {
  const GameHeader({super.key, required this.gameId});

  final int gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var size = MediaQuery.of(context).size;
    var gogState = ref.watch(gogStateProvider);
    return Container(
      height: 316,
      decoration: AppDecorations.card(blurRadius: 18, spreadRadius: 8),
      child: Stack(
        children: [
          Positioned.fill(
            child: AsyncCoverImage(
              imageUrl: gogState.getGameBackgroundLink(gameId),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            bottom: 0,
            child: Container(
              width: size.width * 2 / 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.card),
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
                    future: gogState.getGameName(gameId),
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
                  Container(
                    child: Row(
                      children: [
                        Text(
                          "Not installed",
                          style: AppText.onest(
                            color: Colors.white.withAlpha(196),
                            size: 12,
                            weight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  PrimaryButton(
                    onTap: () {},
                    glowing: true,
                    child: Row(
                      spacing: 8,
                      children: [
                        Icon(Icons.arrow_downward, color: Colors.black),
                        Text(
                          "Install",
                          style: AppText.onest(
                            color: Colors.black,
                            size: 16,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
