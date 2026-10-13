import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/components/game_card.dart';
import 'package:lumen/screens/home/home_screen.dart';
import 'package:lumen/screens/home/pages/library/builds_tab.dart';
import 'package:lumen/state/home_state.dart';
import 'package:lumen/state/library_state.dart';

import '../helpers/fake_gog_backend.dart';
import '../helpers/pump_app.dart';

/// v1.4.0 Phase 3: the selected game and its details tab survive switching
/// nav tabs.
void main() {
  Future<void> pumpFrames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  FakeGogBackend backend() => FakeGogBackend()
    ..ownedGames = [1, 2]
    ..titles[1] = 'One'
    ..titles[2] = 'Two';

  testWidgets('the details view and its tab survive a nav round trip', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      const HomeScreen(),
      backend: backend(),
    );
    await pumpFrames(tester);

    await tester.tap(find.byType(GameCard).first);
    await pumpFrames(tester);
    container
        .read(librarySelectionProvider.notifier)
        .selectTab(SelectedTab.builds);
    await pumpFrames(tester);
    expect(find.byType(GameCard), findsNothing);

    final nav = container.read(navBarItemProvider.notifier);
    nav.select(NavBarItem.downloads);
    await pumpFrames(tester);
    nav.select(NavBarItem.library);
    await pumpFrames(tester);

    expect(find.byType(GameCard), findsNothing);
    final selection = container.read(librarySelectionProvider);
    expect(selection?.tab, SelectedTab.builds);
    expect(find.byType(BuildsTab), findsOneWidget);
  });

  testWidgets('Back clears the selection and shows the grid', (tester) async {
    final container = await pumpApp(
      tester,
      const HomeScreen(),
      backend: backend(),
    );
    await pumpFrames(tester);

    await tester.tap(find.byType(GameCard).first);
    await pumpFrames(tester);
    expect(container.read(librarySelectionProvider), isNotNull);

    // The back pill shares its label with the nav bar's Library tab.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await pumpFrames(tester);

    expect(container.read(librarySelectionProvider), isNull);
    expect(find.byType(GameCard), findsNWidgets(2));
  });

  testWidgets('a selection missing from the refreshed list shows the grid', (
    tester,
  ) async {
    final fake = backend();
    final container = await pumpApp(tester, const HomeScreen(), backend: fake);
    await pumpFrames(tester);

    container.read(librarySelectionProvider.notifier).select(2);
    await pumpFrames(tester);
    expect(find.byType(GameCard), findsNothing);

    fake.ownedGames = [1];
    container.invalidate(ownedGamesProvider);
    await pumpFrames(tester);
    await pumpFrames(tester);

    expect(container.read(librarySelectionProvider), isNull);
    expect(find.byType(GameCard), findsOneWidget);
  });
}
