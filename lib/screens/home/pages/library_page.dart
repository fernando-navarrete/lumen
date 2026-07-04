import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl2_flutter/components/async_cover_image.dart';
import 'package:gogdl2_flutter/components/game_card.dart';
import 'package:gogdl2_flutter/components/primary_button.dart';
import 'package:gogdl2_flutter/state/gog_state.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';
import 'package:gogdl2_flutter/theme/app_decorations.dart';
import 'package:gogdl2_flutter/theme/text_styles.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  int? selectedGame;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: (selectedGame == null)
          ? Column(
              children: [
                SizedBox(height: 24),
                _Library(
                  onGameTap: (gameId) {
                    setState(() {
                      selectedGame = gameId;
                    });
                  },
                ),
              ],
            )
          : _LibraryItem(
              gameId: selectedGame!,
              goBack: () {
                setState(() {
                  selectedGame = null;
                });
              },
            ),
    );
  }
}

class _Library extends ConsumerWidget {
  final Function(int) onGameTap;

  const _Library({required this.onGameTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var size = MediaQuery.of(context).size;
    var gogState = ref.watch(gogStateProvider);
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
                        return GameCard(
                          gameId: gameId,
                          gameName: title,
                          onTap: () {
                            onGameTap(gameId);
                          },
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

class _LibraryItem extends StatelessWidget {
  final int gameId;
  final Function() goBack;

  const _LibraryItem({required this.gameId, required this.goBack});

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size.width * 0.05,
        vertical: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PrimaryButton(
                onTap: goBack,
                child: Row(
                  spacing: 8,
                  children: [
                    Icon(Icons.arrow_back, color: Colors.grey),
                    Text(
                      'Library',
                      style: AppText.onest(
                        color: Colors.grey,
                        size: 16.0,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: SizedBox()),
            ],
          ),
          SizedBox(height: 24),
          _GameHeader(gameId: gameId),
          SizedBox(height: 24),
          Expanded(child: _GameInfo(gameId: gameId)),
        ],
      ),
    );
  }
}

enum SelectedTab { overview, builds, settings }

class _GameInfo extends ConsumerStatefulWidget {
  final int? gameId;

  const _GameInfo({this.gameId});

  @override
  _GameInfoState createState() => _GameInfoState();
}

class _GameInfoState extends ConsumerState<_GameInfo> {
  SelectedTab _selectedTab = SelectedTab.overview;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border12)),
          ),
          child: Row(
            children: [
              _TabButton(
                isSelected: _selectedTab == SelectedTab.overview,
                label: 'Overview',
                onPressed: () {
                  setState(() {
                    _selectedTab = SelectedTab.overview;
                  });
                },
              ),
              _TabButton(
                isSelected: _selectedTab == SelectedTab.builds,
                label: 'Builds',
                onPressed: () {
                  setState(() {
                    _selectedTab = SelectedTab.builds;
                  });
                },
              ),
              _TabButton(
                isSelected: _selectedTab == SelectedTab.settings,
                label: 'Settings',
                onPressed: () {
                  setState(() {
                    _selectedTab = SelectedTab.settings;
                  });
                },
              ),
            ],
          ),
        ),
        SizedBox(height: 24),
        Expanded(
          child: switch (_selectedTab) {
            SelectedTab.overview => Text('overview'),
            SelectedTab.builds => _BuildsTab(selectedGameId: widget.gameId!),
            SelectedTab.settings => Text('settings'),
          },
        ),
      ],
    );
  }
}

class _BuildsTab extends ConsumerWidget {
  final int _selectedGameId;

  const _BuildsTab({required this._selectedGameId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    GogState gogState = ref.watch(gogStateProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select which build to install. Switching re-downloads the changed files.',
          style: AppText.onest(
            size: 12.0,
            weight: FontWeight.w400,
            color: Colors.grey,
          ),
        ),
        SizedBox(height: 16),
        Expanded(
          child: FutureBuilder(
            future: gogState.getBuilds(_selectedGameId),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(snapshot.data![index].versionName),
                      subtitle: Text(
                        snapshot.data![index].releaseDate.replaceAll(
                          RegExp(r'\+0000'),
                          '',
                        ),
                      ),
                      onTap: () {},
                    );
                  },
                );
              }
              return Center(child: CircularProgressIndicator());
            },
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isSelected;

  const _TabButton({
    required this.label,
    required this.onPressed,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          border: isSelected
              ? Border(bottom: BorderSide(color: AppColors.primary, width: 2.0))
              : null,
        ),
        child: Text(
          label,
          style: AppText.onest(
            size: 14.0,
            weight: isSelected ? FontWeight.w500 : FontWeight.w400,
            color: isSelected ? Colors.white : Colors.grey,
          ),
        ),
      ),
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
    );
  }
}
