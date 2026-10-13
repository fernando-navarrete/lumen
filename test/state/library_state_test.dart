import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/models/downloadable_product.dart';
import 'package:lumen/models/game_build.dart';
import 'package:lumen/models/proton_release.dart';
import 'package:lumen/models/proton_release_page.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/library_state.dart';

import '../helpers/container.dart';
import '../helpers/fake_gog_backend.dart';

const _build = GameBuild(
  buildId: '1',
  versionName: '1.0',
  releaseDate: '2024-01-01',
  releaseDateTimestamp: 1,
);

void main() {
  group('ownedGamesProvider', () {
    test('resolves sorted, and a second read does not refetch', () async {
      final backend = FakeGogBackend()..ownedGames = [30, 10, 20];
      final container = await createContainer(backend: backend);

      expect(await container.read(ownedGamesProvider.future), [10, 20, 30]);
      expect(await container.read(ownedGamesProvider.future), [10, 20, 30]);

      expect(backend.callsTo('getOwnedGames'), hasLength(1));
    });

    test('an empty library is data, not an error', () async {
      final container = await createContainer();

      expect(await container.read(ownedGamesProvider.future), isEmpty);
      expect(container.read(ownedGamesProvider).hasError, isFalse);
    });

    test('a failure is an AsyncError and is not retried on its own', () async {
      final backend = FakeGogBackend()
        ..throwOn['getOwnedGames'] = Exception('boom');
      final container = await createContainer(backend: backend);

      await expectLater(
        container.read(ownedGamesProvider.future),
        throwsA(isA<MetadataUnavailableError>()),
      );
      await Future<void>.delayed(const Duration(seconds: 1));

      expect(backend.callsTo('getOwnedGames'), hasLength(1));
    });

    test('invalidate refetches', () async {
      final backend = FakeGogBackend()
        ..throwOn['getOwnedGames'] = Exception('boom');
      final container = await createContainer(backend: backend);
      await expectLater(
        container.read(ownedGamesProvider.future),
        throwsA(isA<MetadataUnavailableError>()),
      );

      backend.throwOn.clear();
      backend.ownedGames = [5];
      container.invalidate(ownedGamesProvider);

      expect(await container.read(ownedGamesProvider.future), [5]);
      expect(backend.callsTo('getOwnedGames'), hasLength(2));
    });
  });

  group('gameTitleProvider', () {
    test(
      'caches per game, fails to AsyncError, refetches on invalidate',
      () async {
        final backend = FakeGogBackend()..titles[1] = 'One';
        final container = await createContainer(backend: backend);

        expect(await container.read(gameTitleProvider(1).future), 'One');
        expect(await container.read(gameTitleProvider(1).future), 'One');
        expect(backend.callsTo('getGameTitle'), hasLength(1));

        backend.throwOn['getGameTitle'] = Exception('boom');
        await expectLater(
          container.read(gameTitleProvider(2).future),
          throwsA(isA<MetadataUnavailableError>()),
        );

        backend.throwOn.clear();
        backend.titles[2] = 'Two';
        container.invalidate(gameTitleProvider(2));
        expect(await container.read(gameTitleProvider(2).future), 'Two');
      },
    );

    test('readGameTitle returns null instead of throwing', () async {
      final backend = FakeGogBackend()
        ..throwOn['getGameTitle'] = Exception('boom');
      final container = await createContainer(backend: backend);

      expect(await readGameTitle(container.read, 1), isNull);
    });
  });

  group('summary and screenshots', () {
    test('succeed, and fall back to empty on failure', () async {
      final backend = FakeGogBackend()
        ..summaries[1] = 'About'
        ..screenshots[1] = ['a.jpg'];
      final container = await createContainer(backend: backend);

      expect(await container.read(gameSummaryProvider(1).future), 'About');
      expect(await container.read(gameScreenshotsProvider(1).future), [
        'a.jpg',
      ]);

      backend.throwOn['getGameSummary'] = Exception('boom');
      backend.throwOn['getGameScreenshots'] = Exception('boom');
      expect(await container.read(gameSummaryProvider(2).future), '');
      expect(await container.read(gameScreenshotsProvider(2).future), isEmpty);
    });
  });

  group('gameBuildsProvider', () {
    test('caches, errors, and refetches on invalidate', () async {
      final backend = FakeGogBackend()..builds[1] = [_build];
      final container = await createContainer(backend: backend);

      expect(await container.read(gameBuildsProvider(1).future), [_build]);
      await container.read(gameBuildsProvider(1).future);
      expect(backend.callsTo('getGameBuilds'), hasLength(1));

      container.invalidate(gameBuildsProvider(1));
      await container.read(gameBuildsProvider(1).future);
      expect(backend.callsTo('getGameBuilds'), hasLength(2));

      backend.throwOn['getGameBuilds'] = Exception('boom');
      await expectLater(
        container.read(gameBuildsProvider(2).future),
        throwsA(isA<MetadataUnavailableError>()),
      );
    });
  });

  group('gameProductsProvider', () {
    test('caches per game and build, and errors on failure', () async {
      const dlc = DownloadableProduct(id: 2, name: 'DLC', productType: 'DLC');
      final backend = FakeGogBackend()..products[1] = [dlc];
      final container = await createContainer(backend: backend);
      const key = (gameId: 1, buildName: '1.0');

      expect(await container.read(gameProductsProvider(key).future), [dlc]);
      await container.read(gameProductsProvider(key).future);
      expect(backend.callsTo('getDownloadableProducts'), hasLength(1));

      backend.throwOn['getDownloadableProducts'] = Exception('boom');
      await expectLater(
        container.read(
          gameProductsProvider((gameId: 1, buildName: '2.0')).future,
        ),
        throwsA(isA<MetadataUnavailableError>()),
      );
    });
  });

  group('protonReleasesProvider', () {
    test(
      'caches per page, errors on failure, refetches on invalidate',
      () async {
        const release = ProtonRelease(tagName: 'GE-Proton9-1', downloadSize: 1);
        final backend = FakeGogBackend()
          ..protonReleasePages[1] = const ProtonReleasePage(
            releases: [release],
            hasMore: true,
          );
        final container = await createContainer(backend: backend);

        final page = await container.read(protonReleasesProvider(1).future);
        expect(page.releases, [release]);
        expect(page.hasMore, true);
        await container.read(protonReleasesProvider(1).future);
        expect(backend.callsTo('getProtonReleasePage'), hasLength(1));

        backend.throwOn['getProtonReleasePage'] = Exception('boom');
        await expectLater(
          container.read(protonReleasesProvider(2).future),
          throwsA(isA<MetadataUnavailableError>()),
        );

        backend.throwOn.clear();
        container.invalidate(protonReleasesProvider(2));
        await container.read(protonReleasesProvider(2).future);
        expect(backend.callsTo('getProtonReleasePage'), hasLength(3));
      },
    );
  });

  group('title concurrency', () {
    test('at most metadataFetchConcurrency lookups are in flight', () async {
      final ids = List.generate(20, (i) => i + 1);
      final gate = Completer<void>();
      var inFlight = 0;
      var peak = 0;
      final backend = FakeGogBackend()..ownedGames = ids;
      for (final id in ids) {
        backend.titles[id] = 'Game $id';
      }
      backend.delayOn['getGameTitle'] = (_) async {
        peak = peak < ++inFlight ? inFlight : peak;
        await gate.future;
        inFlight--;
      };
      final container = await createContainer(backend: backend);

      final all = Future.wait([
        for (final id in ids) container.read(gameTitleProvider(id).future),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(inFlight, metadataFetchConcurrency);

      gate.complete();
      expect(await all, [for (final id in ids) 'Game $id']);
      expect(peak, metadataFetchConcurrency);
    });

    test('a failed title does not fail the others', () async {
      final backend = FakeGogBackend()
        ..titles[1] = 'One'
        ..titles[3] = 'Three';
      final container = await createContainer(backend: backend);

      expect(await container.read(gameTitleProvider(1).future), 'One');
      backend.throwOn['getGameTitle'] = Exception('boom');
      await expectLater(
        container.read(gameTitleProvider(2).future),
        throwsA(isA<MetadataUnavailableError>()),
      );
      backend.throwOn.clear();
      expect(await container.read(gameTitleProvider(3).future), 'Three');
      expect(container.read(gameTitleProvider(1)).value, 'One');
    });
  });

  group('LibraryRefresher', () {
    test('picks up a new game, retries failed titles only', () async {
      final backend = FakeGogBackend()
        ..ownedGames = [1, 2]
        ..titles[1] = 'One'
        ..titles[2] = 'Two'
        ..throwOn['getGameTitle'] = Exception('boom');
      final container = await createContainer(backend: backend);
      await container.read(ownedGamesProvider.future);
      // Title 1 fails now; fix it for 2 by loading it before the failure.
      backend.throwOn.clear();
      await container.read(gameTitleProvider(2).future);
      backend.throwOn['getGameTitle'] = Exception('boom');
      await expectLater(
        container.read(gameTitleProvider(1).future),
        throwsA(isA<MetadataUnavailableError>()),
      );
      backend.throwOn.clear();
      backend.ownedGames = [1, 2, 3];
      final before = backend.callsTo('getGameTitle').length;

      expect(await container.read(libraryRefresherProvider).refresh(), isTrue);

      expect(await container.read(ownedGamesProvider.future), [1, 2, 3]);
      expect(await container.read(gameTitleProvider(1).future), 'One');
      expect(
        backend
            .callsTo('getGameTitle')
            .skip(before)
            .map((c) => c.args['gameId']),
        [1],
      );
    });

    test('clears the backend cache before refetching the owned list', () async {
      final backend = FakeGogBackend()..ownedGames = [1];
      final container = await createContainer(backend: backend);
      await container.read(ownedGamesProvider.future);
      backend.calls.clear();

      await container.read(libraryRefresherProvider).refresh();

      final methods = backend.calls.map((c) => c.method).toList();
      expect(methods.indexOf('clearCache'), isNonNegative);
      expect(
        methods.indexOf('clearCache'),
        lessThan(methods.indexOf('getOwnedGames')),
      );
    });

    test(
      'a failed refresh returns false and keeps the previous list',
      () async {
        final backend = FakeGogBackend()..ownedGames = [1];
        final container = await createContainer(backend: backend);
        await container.read(ownedGamesProvider.future);
        backend.throwOn['getOwnedGames'] = Exception('boom');

        expect(
          await container.read(libraryRefresherProvider).refresh(),
          isFalse,
        );

        expect(container.read(ownedGamesProvider).value, [1]);
      },
    );
  });

  group('gameUpdateProvider', () {
    GameBuild build(String name, int ts) => GameBuild(
      buildId: name,
      versionName: name,
      releaseDate: '2024',
      releaseDateTimestamp: ts,
    );
    String installedOn(String name) =>
        '{"version": 1, "games": {"1": {"status": "downloaded", '
        '"selectedBuild": "$name", "productIds": [1]}}}';

    test('a newer listed build is the update', () async {
      final backend = FakeGogBackend()
        ..builds[1] = [build('2.0', 20), build('1.0', 10)];
      final container = await createContainer(
        backend: backend,
        prefs: {'games': installedOn('1.0')},
      );
      container.listen(gameUpdateProvider(1), (_, _) {});
      await container.read(gameBuildsProvider(1).future);
      expect(container.read(gameUpdateProvider(1))?.versionName, '2.0');
    });

    test('null when on the latest, delisted, loading, or failed', () async {
      final backend = FakeGogBackend()..builds[1] = [build('2.0', 20)];
      var container = await createContainer(
        backend: backend,
        prefs: {'games': installedOn('2.0')},
      );
      container.listen(gameUpdateProvider(1), (_, _) {});
      expect(container.read(gameUpdateProvider(1)), isNull); // loading
      await container.read(gameBuildsProvider(1).future);
      expect(container.read(gameUpdateProvider(1)), isNull); // latest

      container = await createContainer(
        backend: backend,
        prefs: {'games': installedOn('0.1-delisted')},
      );
      container.listen(gameUpdateProvider(1), (_, _) {});
      await container.read(gameBuildsProvider(1).future);
      expect(container.read(gameUpdateProvider(1)), isNull);

      backend.throwOn['getGameBuilds'] = Exception('boom');
      container = await createContainer(
        backend: backend,
        prefs: {'games': installedOn('1.0')},
      );
      container.listen(gameUpdateProvider(1), (_, _) {});
      await container
          .read(gameBuildsProvider(1).future)
          .then((_) {}, onError: (_) {});
      expect(container.read(gameUpdateProvider(1)), isNull);
    });

    test('a game that is not installed never fetches builds', () async {
      final backend = FakeGogBackend()..builds[1] = [build('2.0', 20)];
      final container = await createContainer(backend: backend);
      container.listen(gameUpdateProvider(1), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(container.read(gameUpdateProvider(1)), isNull);
      expect(backend.callsTo('getGameBuilds'), isEmpty);
    });

    test('clears once the installed build is the latest', () async {
      final backend = FakeGogBackend()
        ..builds[1] = [build('2.0', 20), build('1.0', 10)];
      final container = await createContainer(
        backend: backend,
        prefs: {'games': installedOn('1.0')},
      );
      container.listen(gameUpdateProvider(1), (_, _) {});
      await container.read(gameBuildsProvider(1).future);
      expect(container.read(gameUpdateProvider(1)), isNotNull);
      container.read(gamesStateProvider.notifier).setSelectedBuild(1, '2.0');
      expect(container.read(gameUpdateProvider(1)), isNull);
    });

    test('refresh surfaces a build published after the first load', () async {
      final backend = FakeGogBackend()
        ..ownedGames = [1]
        ..titles[1] = 'One'
        ..builds[1] = [build('1.0', 10)];
      final container = await createContainer(
        backend: backend,
        prefs: {'games': installedOn('1.0')},
      );
      container.listen(gameUpdateProvider(1), (_, _) {});
      await container.read(ownedGamesProvider.future);
      await container.read(gameBuildsProvider(1).future);
      expect(container.read(gameUpdateProvider(1)), isNull);

      backend.builds[1] = [build('2.0', 20), build('1.0', 10)];
      await container.read(libraryRefresherProvider).refresh();
      await container.read(gameBuildsProvider(1).future);
      expect(container.read(gameUpdateProvider(1))?.versionName, '2.0');
    });
  });
}
