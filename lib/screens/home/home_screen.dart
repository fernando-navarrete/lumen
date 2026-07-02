import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl2_flutter/components/glowing_square.dart';
import 'package:gogdl2_flutter/components/gradient_background.dart';
import 'package:gogdl2_flutter/state/gog_state.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';
import 'package:gogdl2_flutter/theme/text_styles.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: Column(children: [_NavBar(), _Library()]),
      ),
    );
  }
}

class _Library extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var size = MediaQuery.of(context).size;
    var gogStage = ref.watch(gogStateProvider);

    var ownedGames = gogStage.getOwnedGames();
    return Expanded(
      child: FutureBuilder<List<int>?>(
        future: ownedGames,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: size.width ~/ 200,
              ),
              itemBuilder: (context, index) {
                return FutureBuilder<String?>(
                  future: gogStage.getGameName(snapshot.data![index]),
                  builder: (context, nameSnapshot) {
                    if (nameSnapshot.hasData) {
                      return Text(nameSnapshot.data!);
                    } else {
                      return CircularProgressIndicator();
                    }
                  },
                );
              },
              itemCount: snapshot.data?.length,
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24),
      height: 74,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(8),
        border: Border(bottom: BorderSide(color: AppColors.border08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GlowingSquare(width: 27),
          SizedBox(width: 12),
          Text(
            "Lumen",
            style: AppText.onest(
              size: 18,
              weight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
