import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/components/gradient_background.dart';
import 'package:lumen/components/nav_bar.dart';
import 'package:lumen/screens/home/pages/downloads_page.dart';
import 'package:lumen/screens/home/pages/library/library_page.dart';
import 'package:lumen/screens/home/pages/settings_page.dart';
import 'package:lumen/state/home_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(navBarItemProvider);
    return Scaffold(
      body: GradientBackground(
        child: Column(
          children: [
            const NavBar(),
            Expanded(child: _Content(item: item)),
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
        return const SettingsPage();
    }
  }
}
