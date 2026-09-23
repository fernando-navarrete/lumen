import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/shared_preferences_provider.dart';

import '../helpers/container.dart';

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

      final savedJson = container
          .read(sharedPreferencesProvider)
          .getString('games');
      expect(savedJson, isNotNull);

      final reloaded = await createContainer(prefs: {'games': savedJson!});
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

    test('legacy string-encoded productIds are tolerated on load', () async {
      const json =
          '{"1": {"status": "downloaded", "selectedBuild": "b", '
          '"productIds": ["123", 456]}}';

      final container = await createContainer(prefs: {'games': json});

      expect(container.read(gamesStateProvider).getProductIds(1), {123, 456});
    });

    test('a "downloading" status is coerced to notInstalled on load', () async {
      const json =
          '{"1": {"status": "downloading", "selectedBuild": "b", '
          '"productIds": []}}';

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
