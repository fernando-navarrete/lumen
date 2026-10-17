import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/components/centered_loader.dart';
import 'package:lumen/components/game_card.dart';
import 'package:lumen/components/hero_banner.dart';
import 'package:lumen/models/game_build.dart';
import 'package:lumen/screens/home/pages/library/library_page.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/home_state.dart';

import '../helpers/fake_gog_backend.dart';
import '../helpers/pump_app.dart';

/// Regression `v1.0.6`: the Library page shows an error/empty state with a
/// Retry, instead of spinning forever.
void main() {
  testWidgets('a failed getOwnedGames shows an error message with Retry', (
    tester,
  ) async {
    final backend = FakeGogBackend()
      ..throwOn['getOwnedGames'] = Exception('boom');

    await pumpApp(tester, const LibraryPage(), backend: backend);
    await tester.pump(); // run the post-frame callback that starts _load
    await tester.pump(); // let the failed future resolve

    expect(find.text("Couldn't load your library."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('an empty library shows an empty-state message with Retry', (
    tester,
  ) async {
    final backend = FakeGogBackend()..ownedGames = [];

    await pumpApp(tester, const LibraryPage(), backend: backend);
    await tester.pump();
    await tester.pump();

    expect(find.text('No games in your library.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('tapping Retry after clearing the failure loads the library', (
    tester,
  ) async {
    final backend = FakeGogBackend()
      ..throwOn['getOwnedGames'] = Exception('boom');

    await pumpApp(tester, const LibraryPage(), backend: backend);
    await tester.pump();
    await tester.pump();

    expect(find.text("Couldn't load your library."), findsOneWidget);

    backend.throwOn.clear();
    backend.ownedGames = [1];
    backend.titles[1] = 'A Great Game';

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(); // getOwnedGames resolves
    await tester.pump(); // per-game getGameName resolves

    expect(find.text('A Great Game'), findsWidgets);
    expect(backend.callsTo('getOwnedGames'), hasLength(2));
  });

  testWidgets('a failed title leaves the other cards shown', (tester) async {
    final backend = FakeGogBackend()
      ..ownedGames = [1, 2]
      ..titles[2] = 'Two';
    backend.delayOn['getGameTitle'] = (args) async {
      if (args['gameId'] == 1) throw Exception('boom');
    };

    await pumpApp(tester, const LibraryPage(), backend: backend);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byType(GameCard), findsNWidgets(2));
    expect(find.text('Two'), findsWidgets);
    expect(find.text('Game 1'), findsWidgets);
  });

  group('untitled games', () {
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
    }

    testWidgets('a loading title shows a counted skeleton card', (
      tester,
    ) async {
      final gate = Completer<void>();
      final backend = FakeGogBackend()
        ..ownedGames = [1, 2]
        ..titles[1] = 'One'
        ..titles[2] = 'Two';
      backend.delayOn['getGameTitle'] = (args) async {
        if (args['gameId'] == 1) await gate.future;
      };
      await pumpApp(tester, const LibraryPage(), backend: backend);
      await settle(tester);

      expect(find.byType(GameCard), findsNWidgets(2));
      expect(find.text('2 games'), findsOneWidget);
      expect(find.text('One'), findsNothing);

      gate.complete();
      await settle(tester);
      expect(find.text('One'), findsWidgets);
    });

    testWidgets('a card decodes its boxart at the card width', (tester) async {
      final backend = FakeGogBackend()
        ..ownedGames = [1]
        ..titles[1] = 'One'
        ..boxartLinks[1] = 'https://example.invalid/box.jpg';
      await pumpApp(tester, const LibraryPage(), backend: backend);
      await settle(tester);

      final finder = find.descendant(
        of: find.byType(GameCard),
        matching: find.byType(Image),
      );
      expect(finder, findsOneWidget);
      final provider = tester.widget<Image>(finder).image;
      expect(provider, isA<ResizeImage>());
      final expected =
          (tester.getSize(finder).width * tester.view.devicePixelRatio).ceil();
      expect((provider as ResizeImage).width, expected);
    });

    testWidgets('the hero and the card share one getGameLinks call', (
      tester,
    ) async {
      final backend = FakeGogBackend()
        ..ownedGames = [1]
        ..titles[1] = 'One'
        ..boxartLinks[1] = 'https://example.invalid/box.jpg'
        ..backgroundLinks[1] = 'https://example.invalid/bg.jpg';
      await pumpApp(tester, const LibraryPage(), backend: backend);
      await settle(tester);

      expect(find.byType(HeroBanner), findsOneWidget);
      expect(find.byType(GameCard), findsOneWidget);
      expect(backend.callsTo('getGameLinks'), hasLength(1));
    });

    testWidgets('a failed title card opens the game', (tester) async {
      final backend = FakeGogBackend()..ownedGames = [1];
      backend.throwOn['getGameTitle'] = Exception('boom');
      final container = await pumpApp(
        tester,
        const LibraryPage(),
        backend: backend,
      );
      await settle(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(GameCard),
          matching: find.text('Game 1'),
        ),
      );
      await tester.pump();
      expect(container.read(librarySelectionProvider)?.gameId, 1);
    });

    testWidgets('search matches the fallback name', (tester) async {
      final backend = FakeGogBackend()
        ..ownedGames = [1, 2]
        ..titles[2] = 'Two';
      backend.delayOn['getGameTitle'] = (args) async {
        if (args['gameId'] == 1) throw Exception('boom');
      };
      final container = await pumpApp(
        tester,
        const LibraryPage(),
        backend: backend,
      );
      await settle(tester);
      container.read(librarySearchProvider.notifier).set('game 1');
      await settle(tester);

      expect(find.byType(GameCard), findsOneWidget);
    });

    testWidgets('the hero skips a game whose title failed', (tester) async {
      final backend = FakeGogBackend()
        ..ownedGames = [1, 2]
        ..titles[2] = 'Two';
      backend.delayOn['getGameTitle'] = (args) async {
        if (args['gameId'] == 1) throw Exception('boom');
      };
      await pumpApp(tester, const LibraryPage(), backend: backend);
      await settle(tester);

      expect(
        find.descendant(
          of: find.byType(HeroBanner),
          matching: find.text('Two'),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('Refresh keeps the grid visible, then shows the new game', (
    tester,
  ) async {
    final backend = FakeGogBackend()
      ..ownedGames = [1]
      ..titles[1] = 'One'
      ..titles[2] = 'Two';
    await pumpApp(tester, const LibraryPage(), backend: backend);
    await tester.pump();
    await tester.pump();
    expect(find.byType(GameCard), findsOneWidget);

    final gate = Completer<void>();
    backend.delayOn['getOwnedGames'] = (_) => gate.future;
    backend.ownedGames = [1, 2];
    await tester.tap(find.text('Refresh'));
    await tester.pump();

    expect(find.byType(GameCard), findsOneWidget);
    expect(find.byType(CenteredLoader), findsNothing);

    gate.complete();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byType(GameCard), findsNWidgets(2));
  });

  testWidgets('a failed Refresh keeps the grid and shows a snackbar', (
    tester,
  ) async {
    final backend = FakeGogBackend()
      ..ownedGames = [1]
      ..titles[1] = 'One';
    await pumpApp(tester, const LibraryPage(), backend: backend);
    await tester.pump();
    await tester.pump();

    backend.throwOn['getOwnedGames'] = Exception('boom');
    await tester.tap(find.text('Refresh'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text("Couldn't refresh your library."), findsOneWidget);
    expect(find.byType(GameCard), findsOneWidget);
  });

  group('status filters', () {
    const games =
        '{"version": 3, "games": {'
        '"1": {"status": "downloaded", "selectedBuild": "1", "installPath": "/g1"}, '
        '"2": {"status": "downloading", "selectedBuild": "1", "pendingInstallPath": "/g2"}, '
        '"3": {"status": "paused", "selectedBuild": "1", "pendingInstallPath": "/g3"}}}';

    Future<ProviderContainer> pumpLibrary(
      WidgetTester tester, {
      Map<String, Object> prefs = const {'games': games},
    }) async {
      final backend = FakeGogBackend()
        ..ownedGames = [1, 2, 3, 4]
        ..titles.addAll({1: 'One', 2: 'Two', 3: 'Three', 4: 'Four'});
      final container = await pumpApp(
        tester,
        const LibraryPage(),
        backend: backend,
        prefs: prefs,
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      return container;
    }

    Future<void> choose(WidgetTester tester, String chip) async {
      await tester.tap(find.text(chip));
      await tester.pump();
    }

    testWidgets('each chip matches its own statuses', (tester) async {
      await pumpLibrary(tester);
      expect(find.text('4 games'), findsOneWidget);

      await choose(tester, 'Installed');
      expect(find.text('1 games'), findsOneWidget);
      expect(find.widgetWithText(GameCard, 'One'), findsOneWidget);
      expect(find.widgetWithText(GameCard, 'Two'), findsNothing);

      await choose(tester, 'Installing');
      expect(find.text('2 games'), findsOneWidget);
      expect(find.widgetWithText(GameCard, 'Two'), findsOneWidget);
      expect(find.widgetWithText(GameCard, 'Three'), findsOneWidget);
      expect(find.widgetWithText(GameCard, 'One'), findsNothing);

      await choose(tester, 'Not installed');
      expect(find.text('1 games'), findsOneWidget);
      expect(find.widgetWithText(GameCard, 'Four'), findsOneWidget);
    });

    testWidgets('the Installing chip appears with an installing game', (
      tester,
    ) async {
      final container = await pumpLibrary(
        tester,
        prefs: const {
          'games':
              '{"version": 3, "games": {"1": {"status": "downloaded", '
              '"selectedBuild": "1", "installPath": "/g1"}, "2": {"status": "notInstalled", "selectedBuild": "1"}}}',
        },
      );
      expect(find.text('Installing'), findsNothing);

      container
          .read(gamesStateProvider.notifier)
          .setGameStatus(2, GameStatus.downloading);
      await tester.pump();
      expect(find.text('Installing'), findsWidgets);
    });

    testWidgets('a selected Installing chip that disappears resets to All', (
      tester,
    ) async {
      final container = await pumpLibrary(
        tester,
        prefs: const {
          'games':
              '{"version": 3, "games": {"2": {"status": "paused", '
              '"selectedBuild": "1", "pendingInstallPath": "/g2"}}}',
        },
      );
      await choose(tester, 'Installing');
      expect(find.text('1 games'), findsOneWidget);

      container
          .read(gamesStateProvider.notifier)
          .setGameStatus(2, GameStatus.downloaded);
      await tester.pump();
      await tester.pump();

      expect(find.text('Installing'), findsNothing);
      expect(find.text('4 games'), findsOneWidget);
    });
  });

  group('update badge', () {
    const installed =
        '{"version": 1, "games": {"1": {"status": "downloaded", '
        '"selectedBuild": "1.0", "installPath": "/g", "productIds": [1]}}}';
    GameBuild b(String n, int ts) =>
        GameBuild(buildId: n, versionName: n, releaseDateTimestamp: ts);

    Future<void> pumpLibrary(
      WidgetTester tester,
      FakeGogBackend backend, {
      Map<String, Object> prefs = const {},
    }) async {
      await pumpApp(
        tester,
        const LibraryPage(),
        backend: backend,
        prefs: prefs,
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
    }

    testWidgets('an installed game with a newer build shows it', (
      tester,
    ) async {
      final backend = FakeGogBackend()
        ..ownedGames = [1]
        ..titles[1] = 'Game'
        ..builds[1] = [b('2.0', 2), b('1.0', 1)];
      await pumpLibrary(tester, backend, prefs: {'games': installed});
      expect(find.text('Update available'), findsOneWidget);
    });

    testWidgets('a failed builds fetch shows no badge and no error', (
      tester,
    ) async {
      final backend = FakeGogBackend()
        ..ownedGames = [1]
        ..titles[1] = 'Game'
        ..throwOn['getGameBuilds'] = Exception('boom');
      await pumpLibrary(tester, backend, prefs: {'games': installed});
      expect(find.text('Update available'), findsNothing);
      expect(find.byType(GameCard), findsOneWidget);
    });

    testWidgets('a game that is not installed has none', (tester) async {
      final backend = FakeGogBackend()
        ..ownedGames = [1]
        ..titles[1] = 'Game'
        ..builds[1] = [b('2.0', 2)];
      await pumpLibrary(tester, backend);
      expect(find.text('Update available'), findsNothing);
    });
  });
}
