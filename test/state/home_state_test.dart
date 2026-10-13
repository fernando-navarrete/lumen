import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/state/home_state.dart';

import 'package:lumen/state/library_state.dart';

import '../helpers/container.dart';
import '../helpers/fake_gog_backend.dart';

void main() {
  group('NavBarNotifier', () {
    test('defaults to library', () async {
      final container = await createContainer();
      expect(container.read(navBarItemProvider), NavBarItem.library);
    });

    test('select updates the state each time', () async {
      final container = await createContainer();
      final notifier = container.read(navBarItemProvider.notifier);

      notifier.select(NavBarItem.downloads);
      expect(container.read(navBarItemProvider), NavBarItem.downloads);

      notifier.select(NavBarItem.settings);
      expect(container.read(navBarItemProvider), NavBarItem.settings);
    });

    test('a listener sees each change once, and reselecting the same item '
        'sends no notification', () async {
      final container = await createContainer();
      final notifier = container.read(navBarItemProvider.notifier);
      final seen = <NavBarItem>[];
      container.listen(
        navBarItemProvider,
        (previous, next) => seen.add(next),
        fireImmediately: false,
      );

      notifier.select(NavBarItem.downloads);
      notifier.select(NavBarItem.downloads);
      notifier.select(NavBarItem.settings);

      expect(seen, [NavBarItem.downloads, NavBarItem.settings]);
    });
  });

  group('LibrarySelectionNotifier', () {
    test('defaults to no selection', () async {
      final container = await createContainer();
      expect(container.read(librarySelectionProvider), isNull);
    });

    test(
      'select opens the game on Overview; selectTab changes the tab',
      () async {
        final container = await createContainer();
        final notifier = container.read(librarySelectionProvider.notifier);

        notifier.select(7);
        notifier.selectTab(SelectedTab.builds);
        expect(container.read(librarySelectionProvider), (
          gameId: 7,
          tab: SelectedTab.builds,
        ));

        notifier.select(8);
        expect(container.read(librarySelectionProvider), (
          gameId: 8,
          tab: SelectedTab.overview,
        ));
      },
    );

    test(
      'selectTab with nothing selected does nothing; clear resets',
      () async {
        final container = await createContainer();
        final notifier = container.read(librarySelectionProvider.notifier);

        notifier.selectTab(SelectedTab.dlc);
        expect(container.read(librarySelectionProvider), isNull);

        notifier.select(1);
        notifier.clear();
        expect(container.read(librarySelectionProvider), isNull);
      },
    );

    group('after the owned list changes', () {
      late FakeGogBackend backend;
      late ProviderContainer container;

      setUp(() async {
        backend = FakeGogBackend()..ownedGames = [1, 2];
        container = await createContainer(backend: backend);
        await container.read(ownedGamesProvider.future);
        container.read(librarySelectionProvider.notifier).select(2);
      });

      Future<void> refresh() async {
        container.invalidate(ownedGamesProvider);
        try {
          await container.read(ownedGamesProvider.future);
        } catch (_) {}
      }

      test('a game that disappeared falls back to the grid', () async {
        backend.ownedGames = [1];
        await refresh();
        expect(container.read(librarySelectionProvider), isNull);
      });

      test('a game that is still owned stays selected', () async {
        backend.ownedGames = [2, 3];
        await refresh();
        expect(container.read(librarySelectionProvider)?.gameId, 2);
      });

      test('a failed refresh keeps the selection', () async {
        backend.throwOn['getOwnedGames'] = Exception('boom');
        await refresh();
        expect(container.read(librarySelectionProvider)?.gameId, 2);
      });
    });
  });
}
