import 'package:dir_picker/dir_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl2_flutter/components/async_cover_image.dart';
import 'package:gogdl2_flutter/components/primary_button.dart';
import 'package:gogdl2_flutter/state/downloads_state.dart';
import 'package:gogdl2_flutter/state/games_state.dart';
import 'package:gogdl2_flutter/state/gog_state.dart';
import 'package:gogdl2_flutter/theme/app_decorations.dart';
import 'package:gogdl2_flutter/theme/app_dimens.dart';
import 'package:gogdl2_flutter/theme/text_styles.dart';
import 'package:gogdl2_flutter_bridge/gogdl2_flutter_bridge.dart';

/// Wide banner with the game's background art and its title over a scrim.
class GameHeader extends ConsumerStatefulWidget {
  const GameHeader({super.key, required this.gameId});

  final int gameId;

  @override
  ConsumerState<GameHeader> createState() => _GameHeaderState();
}

class _GameHeaderState extends ConsumerState<GameHeader> {
  /// Whether preloading the default build + products has finished, gating
  /// the Install/Import buttons so they always have something to act on.
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _preload());
  }

  @override
  void didUpdateWidget(covariant GameHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gameId != widget.gameId) {
      setState(() {
        _ready = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _preload());
    }
  }

  GameBuild _latestBuild(List<GameBuild> builds) => builds.reduce(
    (a, b) => b.releaseDateTimestamp > a.releaseDateTimestamp ? b : a,
  );

  /// Preloads the default build (latest) and products (all) for
  /// [widget.gameId], but only fills in defaults when nothing has been
  /// saved yet — a prior user choice is left untouched.
  Future<void> _preload() async {
    final gogState = ref.read(gogStateProvider);
    final gamesState = ref.read(gamesStateProvider);
    final gameId = widget.gameId;

    String? buildName = gamesState.getSelectedBuild(gameId);
    if (buildName == null || buildName.isEmpty) {
      final builds = await gogState.getBuilds(gameId);
      if (builds != null && builds.isNotEmpty) {
        buildName = _latestBuild(builds).versionName;
        gamesState.setSelectedBuild(gameId, buildName);
      }
    }

    if (buildName != null &&
        buildName.isNotEmpty &&
        gamesState.getProductIds(gameId).isEmpty) {
      final products = await gogState.getProducts(gameId, buildName);
      for (final product in products ?? const <DownloadableProduct>[]) {
        gamesState.addProductId(gameId, product.id);
      }
    }

    if (mounted) {
      setState(() {
        _ready =
            (buildName != null && buildName.isNotEmpty) &&
            gamesState.getProductIds(gameId).isNotEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var gameId = widget.gameId;
    var size = MediaQuery.of(context).size;
    var gogState = ref.watch(gogStateProvider);
    var gamesState = ref.watch(gamesStateProvider);
    final bool installed =
        gamesState.getGameStatus(gameId) == GameStatus.downloaded;
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
                  Row(
                    children: [
                      Text(
                        installed ? "Installed" : "Not installed",
                        style: AppText.onest(
                          color: Colors.white.withAlpha(196),
                          size: 12,
                          weight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    spacing: 12,
                    children: installed
                        ? [
                            PrimaryButton(
                              enabled: true,
                              onTap: () {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Play is not implemented yet",
                                    ),
                                  ),
                                );
                              },
                              glowing: true,
                              child: Row(
                                spacing: 8,
                                children: [
                                  Icon(Icons.play_arrow, color: Colors.black),
                                  Text(
                                    "Play",
                                    style: AppText.onest(
                                      color: Colors.black,
                                      size: 16,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]
                        : [
                            PrimaryButton(
                              enabled: _ready,
                              onTap: () async {
                                final PickedLocation? location =
                                    await DirPicker.pick();
                                if (location == null) {
                                  return;
                                }

                                final String path = location.uri!
                                    .toFilePath();
                                final List<String> productIds = gamesState
                                    .getProductIds(gameId)
                                    .toList();
                                final String buildName =
                                    gamesState.getSelectedBuild(gameId) ?? "";
                                if (productIds.isEmpty) {
                                  return;
                                }

                                await ref
                                    .read(downloadsStateProvider)
                                    .startDownload(
                                      gameId,
                                      path: path,
                                      buildName: buildName,
                                      productIds: productIds,
                                    );

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Downloading — check the Downloads tab for progress",
                                      ),
                                    ),
                                  );
                                }
                              },
                              glowing: true,
                              child: Row(
                                spacing: 8,
                                children: [
                                  Icon(
                                    Icons.arrow_downward,
                                    color: Colors.black,
                                  ),
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
                            PrimaryButton.icon(
                              icon: Icons.folder_open,
                              label: "Import",
                              glowing: false,
                              enabled: _ready,
                              onTap: () async {
                                final PickedLocation? location =
                                    await DirPicker.pick();
                                if (location == null) {
                                  return;
                                }

                                final String path = location.uri!
                                    .toFilePath();
                                final List<String> productIds = gamesState
                                    .getProductIds(gameId)
                                    .toList();
                                final String buildName =
                                    gamesState.getSelectedBuild(gameId) ?? "";
                                if (productIds.isEmpty) {
                                  return;
                                }

                                await ref
                                    .read(downloadsStateProvider)
                                    .startVerification(
                                      gameId,
                                      path: path,
                                      buildName: buildName,
                                      productIds: productIds,
                                    );

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Verifying files — check the Downloads tab for progress",
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
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
