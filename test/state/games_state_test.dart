import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/shared_preferences_provider.dart';

import '../helpers/container.dart';

// Real Future.delayed waits rather than fake_async -- same choice made in
// emit_throttle_test.dart -- and GamesNotifier.persistDebounce is short
// enough (500ms) that real waits stay fast.
Future<void> settle() => Future<void>.delayed(
  GamesNotifier.persistDebounce + const Duration(milliseconds: 50),
);

/// Asserts every field of [actual] matches [expected] — [GameConfig] has no
/// `==`, so tests compare field by field instead of relying on object
/// identity.
void expectSameConfig(GameConfig actual, GameConfig expected) {
  expect(actual.status, expected.status, reason: 'status');
  expect(actual.selectedBuild, expected.selectedBuild, reason: 'selectedBuild');
  expect(actual.productIds, expected.productIds, reason: 'productIds');
  expect(actual.installPath, expected.installPath, reason: 'installPath');
  expect(actual.protonVersion, expected.protonVersion, reason: 'protonVersion');
  expect(
    actual.protonPrefixPath,
    expected.protonPrefixPath,
    reason: 'protonPrefixPath',
  );
  expect(actual.executable, expected.executable, reason: 'executable');
  expect(actual.launchArgs, expected.launchArgs, reason: 'launchArgs');
  expect(actual.envVars, expected.envVars, reason: 'envVars');
  expect(actual.launchWrapper, expected.launchWrapper, reason: 'launchWrapper');
}

GameConfig fullConfig() => GameConfig(
  status: GameStatus.downloaded,
  selectedBuild: 'build-1',
  productIds: {1, 2, 3},
  installPath: '/games/foo',
  protonVersion: 'GE-Proton9-1',
  protonPrefixPath: '/prefixes/1',
  executable: 'foo.exe',
  launchArgs: ['-fullscreen'],
  envVars: {'DXVK_HUD': '1'},
  launchWrapper: ['gamescope', '-f', '--'],
);

void main() {
  group('GameConfig.copyWith', () {
    test('omitting a nullable argument keeps its existing value', () {
      final original = fullConfig();

      final copy = original.copyWith(selectedBuild: 'build-2');

      expect(copy.selectedBuild, 'build-2');
      expect(copy.installPath, original.installPath);
      expect(copy.protonVersion, original.protonVersion);
      expect(copy.protonPrefixPath, original.protonPrefixPath);
      expect(copy.executable, original.executable);
      // Non-nullable fields are carried over too.
      expect(copy.status, original.status);
      expect(copy.productIds, original.productIds);
      expect(copy.launchArgs, original.launchArgs);
      expect(copy.envVars, original.envVars);
      expect(copy.launchWrapper, original.launchWrapper);
    });

    test('explicitly passing null clears only that field', () {
      final original = fullConfig();

      final copy = original.copyWith(installPath: null);

      expect(copy.installPath, isNull);
      // The other nullable fields are untouched.
      expect(copy.protonVersion, original.protonVersion);
      expect(copy.protonPrefixPath, original.protonPrefixPath);
      expect(copy.executable, original.executable);
    });

    test('each nullable field can be cleared independently', () {
      final original = fullConfig();

      expect(original.copyWith(protonVersion: null).protonVersion, isNull);
      expect(
        original.copyWith(protonPrefixPath: null).protonPrefixPath,
        isNull,
      );
      expect(original.copyWith(executable: null).executable, isNull);
    });
  });

  group('persistence round-trip', () {
    test('every field survives a save and reload', () async {
      final container = await createContainer();
      final notifier = container.read(gamesStateProvider.notifier);

      const gameId = 42;
      notifier.setSelectedBuild(gameId, 'build-1');
      notifier.markInstalled(gameId, '/games/foo');
      notifier.setProductIds(gameId, {1, 2, 3});
      notifier.setProtonVersion(gameId, 'GE-Proton9-1');
      notifier.setExecutable(gameId, 'foo.exe');
      notifier.setLaunchArgs(gameId, ['-fullscreen']);
      notifier.setEnvVars(gameId, {'DXVK_HUD': '1'});
      notifier.setLaunchWrapper(gameId, ['gamescope', '-f', '--']);
      // setLaunchArgs/setEnvVars/setLaunchWrapper debounce their prefs
      // write -- flush it now instead of waiting persistDebounce out.
      notifier.flushPendingPersist();

      final savedJson = container
          .read(sharedPreferencesProvider)
          .getString('games');
      expect(savedJson, isNotNull);

      // The save is wrapped in a {"version": ..., "games": {...}} envelope,
      // not a bare gameId->entry map.
      final decoded = jsonDecode(savedJson!) as Map<String, dynamic>;
      expect(decoded['version'], GamesNotifier.gamesSchemaVersion);
      expect(decoded['games'], isA<Map<String, dynamic>>());

      final reloaded = await createContainer(prefs: {'games': savedJson});
      final reloadedConfig = reloaded.read(gamesStateProvider).games[gameId];

      expect(reloadedConfig, isNotNull);
      expectSameConfig(
        reloadedConfig!,
        GameConfig(
          status: GameStatus.downloaded,
          selectedBuild: 'build-1',
          productIds: {1, 2, 3},
          installPath: '/games/foo',
          protonVersion: 'GE-Proton9-1',
          executable: 'foo.exe',
          launchArgs: ['-fullscreen'],
          envVars: {'DXVK_HUD': '1'},
          launchWrapper: ['gamescope', '-f', '--'],
        ),
      );
    });

    test('a "downloading" status is coerced to notInstalled on load', () async {
      const json =
          '{"version": 1, "games": {"1": {"status": "downloading", '
          '"selectedBuild": "b", "productIds": []}}}';

      final container = await createContainer(prefs: {'games': json});

      expect(
        container.read(gamesStateProvider).getGameStatus(1),
        GameStatus.notInstalled,
      );
    });

    test('corrupt JSON loads as empty state instead of throwing', () async {
      final container = await createContainer(prefs: {'games': 'not json'});

      expect(container.read(gamesStateProvider).games, isEmpty);
    });
  });

  group('schema migration', () {
    test('a legacy (pre-v1.1.5) bare games map loads correctly', () async {
      // No "version"/"games" envelope -- this is what every prefs file
      // written before v1.1.5 looks like: gameId -> entry directly.
      const json =
          '{"1": {"status": "downloading", "selectedBuild": "b", '
          '"productIds": []}}';

      final container = await createContainer(prefs: {'games': json});

      expect(
        container.read(gamesStateProvider).getGameStatus(1),
        GameStatus.notInstalled,
      );
    });

    test(
      'legacy string-encoded productIds are migrated to ints on load',
      () async {
        const json =
            '{"1": {"status": "downloaded", "selectedBuild": "b", '
            '"productIds": ["123", 456]}}';

        final container = await createContainer(prefs: {'games': json});

        expect(container.read(gamesStateProvider).getProductIds(1), {123, 456});
      },
    );

    test(
      'legacy data is re-saved in the current envelope after a mutation',
      () async {
        const json =
            '{"1": {"status": "downloaded", "selectedBuild": "b", '
            '"productIds": ["123"]}}';

        final container = await createContainer(prefs: {'games': json});
        container.read(gamesStateProvider.notifier).setSelectedBuild(1, 'c');

        final savedJson = container
            .read(sharedPreferencesProvider)
            .getString('games');
        final decoded = jsonDecode(savedJson!) as Map<String, dynamic>;
        expect(decoded['version'], GamesNotifier.gamesSchemaVersion);

        final games = decoded['games'] as Map<String, dynamic>;
        final entry = games['1'] as Map<String, dynamic>;
        // Migrated to an int alongside the version bump.
        expect(entry['productIds'], [123]);
      },
    );

    test('a stored version newer than the app is decoded on a best-effort '
        'basis instead of being rejected', () async {
      final json = jsonEncode({
        'version': GamesNotifier.gamesSchemaVersion + 1,
        'games': {
          '1': {
            'status': 'downloaded',
            'selectedBuild': 'b',
            'productIds': [1, 2],
            // A hypothetical future field this app version doesn't know
            // about; it must simply be ignored, not crash the load.
            'someFutureField': 'value',
          },
        },
      });

      final container = await createContainer(prefs: {'games': json});

      expect(
        container.read(gamesStateProvider).getGameStatus(1),
        GameStatus.downloaded,
      );
      expect(container.read(gamesStateProvider).getProductIds(1), {1, 2});
    });
  });

  group('debounced persistence', () {
    test('setLaunchArgs updates state immediately but debounces the prefs '
        'write; a burst ends with prefs holding only the last value', () async {
      final container = await createContainer();
      final notifier = container.read(gamesStateProvider.notifier);
      const gameId = 1;
      notifier.setSelectedBuild(gameId, 'build-1');

      notifier.setLaunchArgs(gameId, ['-a']);
      notifier.setLaunchArgs(gameId, ['-a', '-b']);
      notifier.setLaunchArgs(gameId, ['-a', '-b', '-c']);

      // In-memory state reflects every call immediately.
      expect(container.read(gamesStateProvider).getLaunchArgs(gameId), [
        '-a',
        '-b',
        '-c',
      ]);
      // But prefs still only reflect setSelectedBuild's immediate write --
      // none of the debounced launchArgs edits have landed yet.
      final beforeSettle = container
          .read(sharedPreferencesProvider)
          .getString('games');
      expect(beforeSettle, contains('"selectedBuild":"build-1"'));
      expect(beforeSettle, isNot(contains('-c')));

      await settle();

      final savedJson = container
          .read(sharedPreferencesProvider)
          .getString('games');
      expect(savedJson, isNotNull);
      final reloaded = await createContainer(prefs: {'games': savedJson!});
      expect(reloaded.read(gamesStateProvider).getLaunchArgs(gameId), [
        '-a',
        '-b',
        '-c',
      ]);
    });

    test(
      'an immediate mutation after a debounced edit persists both at once',
      () async {
        final container = await createContainer();
        final notifier = container.read(gamesStateProvider.notifier);
        const gameId = 1;
        notifier.setSelectedBuild(gameId, 'build-1');

        notifier.setLaunchArgs(gameId, ['-fullscreen']);
        notifier.setProtonVersion(gameId, 'GE-Proton9-1');

        // setProtonVersion is not debounced, so it wrote right away --
        // carrying along the still-pending launchArgs edit.
        final savedJson = container
            .read(sharedPreferencesProvider)
            .getString('games');
        expect(savedJson, isNotNull);
        final reloaded = await createContainer(prefs: {'games': savedJson!});
        final config = reloaded.read(gamesStateProvider).games[gameId]!;
        expect(config.launchArgs, ['-fullscreen']);
        expect(config.protonVersion, 'GE-Proton9-1');
      },
    );

    test('flushPendingPersist writes synchronously', () async {
      final container = await createContainer();
      final notifier = container.read(gamesStateProvider.notifier);
      const gameId = 1;
      notifier.setSelectedBuild(gameId, 'build-1');
      notifier.setLaunchArgs(gameId, ['-fullscreen']);

      notifier.flushPendingPersist();

      expect(
        container.read(sharedPreferencesProvider).getString('games'),
        isNotNull,
      );
    });

    test('disposing the container flushes a pending write', () async {
      final container = await createContainer();
      final notifier = container.read(gamesStateProvider.notifier);
      final prefs = container.read(sharedPreferencesProvider);
      const gameId = 1;
      notifier.setSelectedBuild(gameId, 'build-1');
      notifier.setLaunchArgs(gameId, ['-fullscreen']);

      container.dispose();

      expect(prefs.getString('games'), isNotNull);
    });

    test('clear cancels a pending write', () async {
      final container = await createContainer();
      final notifier = container.read(gamesStateProvider.notifier);
      const gameId = 1;
      notifier.setSelectedBuild(gameId, 'build-1');
      notifier.setLaunchArgs(gameId, ['-fullscreen']);

      await notifier.clear();
      await settle();

      expect(
        container.read(sharedPreferencesProvider).getString('games'),
        isNull,
      );
    });
  });

  test(
    'regression v1.0.2: setSelectedBuild keeps the rest of the config',
    () async {
      final container = await createContainer();
      final notifier = container.read(gamesStateProvider.notifier);
      const gameId = 7;

      notifier.setSelectedBuild(gameId, 'build-1');
      notifier.markInstalled(gameId, '/games/foo');
      notifier.setProductIds(gameId, {1, 2});
      notifier.setProtonVersion(gameId, 'GE-Proton9-1');
      notifier.setExecutable(gameId, 'foo.exe');
      notifier.setLaunchArgs(gameId, ['-fullscreen']);
      notifier.setEnvVars(gameId, {'DXVK_HUD': '1'});
      notifier.setLaunchWrapper(gameId, ['gamescope', '-f', '--']);
      final before = container.read(gamesStateProvider).games[gameId]!;

      notifier.setSelectedBuild(gameId, 'build-2');
      final after = container.read(gamesStateProvider).games[gameId]!;

      expect(after.selectedBuild, 'build-2');
      expectSameConfig(after, before.copyWith(selectedBuild: 'build-2'));
    },
  );
}
