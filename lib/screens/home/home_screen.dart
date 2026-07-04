import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl2_flutter/components/gradient_background.dart';
import 'package:gogdl2_flutter/components/nav_bar.dart';
import 'package:gogdl2_flutter/screens/home/pages/downloads_page.dart';
import 'package:gogdl2_flutter/screens/home/pages/library/library_page.dart';
import 'package:gogdl2_flutter/state/home_state.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return _HomeScreenState();
  }
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    var navBarState = ref.watch(navBarItemProvider);
    return Scaffold(
      body: GradientBackground(
        child: Column(
          children: [
            NavBar(
              onItemSelected: (item) {
                setState(() {
                  navBarState.setItem(item);
                });
              },
            ),
            Expanded(child: _Content(item: navBarState.item)),
          ],
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.item});

  final NavBarItem item;

  @override
  Widget build(BuildContext context) {
    switch (item) {
      case NavBarItem.library:
        return LibraryPage();
      case NavBarItem.downloads:
        return DownloadsPage();
      case NavBarItem.settings:
        return Container();
    }
  }
}
