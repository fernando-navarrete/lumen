import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogdl_flutter/gogdl_flutter.dart'
    hide GameBuild, DownloadableProduct, ProtonRelease;
import 'package:lumen/common/app_paths.dart';
import 'package:lumen/state/downloads_state.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/launch_state.dart';
import 'package:lumen/common/safe_delete.dart';
import 'package:lumen/state/uninstall.dart';

import '../helpers/container.dart';
import '../helpers/fake_gog_backend.dart';
import '../helpers/temp_data_home.dart';

class _RunningLaunchNotifier extends LaunchNotifier {
  @override
  LaunchState build() =>
      LaunchState({1: RunningGame(gameId: 1, status: LaunchStatus.running)});
}

void main() {
  late Directory root;
  late Directory installDir;

  setUp(() {
    useTempDataHome();
    root = Directory.systemTemp.createTempSync('lumen_uninstall');
    addTearDown(() => root.deleteSync(recursive: true));
    installDir = Directory('${root.path}/foo')..createSync();
    File('${installDir.path}/game.exe').writeAsStringSync('x');
  });

  Future<ProviderContainer> installed({
    FakeGogBackend? backend,
    List<Override> overrides = const [],
  }) async {
    final container = await createContainer(
      backend: backend,
      overrides: overrides,
    );
    container
        .read(gamesStateProvider.notifier)
        .markInstalled(1, installDir.path);
    return container;
  }

  Future<void> uninstall(
    ProviderContainer c, {
    bool deleteFiles = true,
    bool deletePrefix = false,
  }) => c
      .read(uninstallerProvider)
      .uninstallGame(1, deleteFiles: deleteFiles, deletePrefix: deletePrefix);

  test('removes the files and the whole config entry', () async {
    final container = await installed();
    final games = container.read(gamesStateProvider.notifier);
    games.setLaunchArgs(1, ['-x']);
    games.setProtonVersion(1, 'GE-Proton1');

    await uninstall(container);

    expect(installDir.existsSync(), isFalse);
    final state = container.read(gamesStateProvider);
    expect(state.games.containsKey(1), isFalse);
    expect(state.getGameStatus(1), GameStatus.notInstalled);
    expect(state.getLaunchArgs(1), isEmpty);
  });

  test(
    'deleteFiles: false keeps the folder but still resets the game',
    () async {
      final container = await installed();

      await uninstall(container, deleteFiles: false);

      expect(installDir.existsSync(), isTrue);
      expect(container.read(gamesStateProvider).games.containsKey(1), isFalse);
    },
  );

  test('the prefix and logs are kept unless asked', () async {
    final prefix = Directory(protonPrefixDir(1))..createSync(recursive: true);
    Directory(logsDir()).createSync(recursive: true);
    File(gameLogPath(1)).writeAsStringSync('log');
    File(previousGameLogPath(1)).writeAsStringSync('old');
    final container = await installed();

    await uninstall(container);
    expect(prefix.existsSync(), isTrue);
    expect(File(gameLogPath(1)).existsSync(), isTrue);

    container
        .read(gamesStateProvider.notifier)
        .markInstalled(1, installDir.path);
    installDir.createSync();
    await uninstall(container, deletePrefix: true);
    expect(prefix.existsSync(), isFalse);
    expect(File(gameLogPath(1)).existsSync(), isFalse);
    expect(File(previousGameLogPath(1)).existsSync(), isFalse);
  });

  test('is refused while the game is running', () async {
    final container = await installed(
      overrides: [launchStateProvider.overrideWith(_RunningLaunchNotifier.new)],
    );

    await expectLater(uninstall(container), throwsA(isA<UninstallError>()));

    expect(installDir.existsSync(), isTrue);
    expect(
      container.read(gamesStateProvider).getGameStatus(1),
      GameStatus.downloaded,
    );
  });

  test('a running repair is stopped before the files are deleted', () async {
    final backend = FakeGogBackend();
    final container = await installed(backend: backend);
    addTearDown(backend.closeAll);
    final downloads = container.read(downloadsStateProvider.notifier);
    await downloads.startRepairForInstalled(
      1,
      path: installDir.path,
      buildName: 'b',
      productIds: [1],
    );
    backend
        .repairController(1)
        .add(RepairGameProgress.verification(checkedBytes: BigInt.one));

    await uninstall(container);

    expect(backend.jobCancel('repairDownload').isCancelled, isTrue);
    expect(installDir.existsSync(), isFalse);
    expect(container.read(downloadsStateProvider).tasks, isEmpty);
    expect(container.read(gamesStateProvider).games.containsKey(1), isFalse);
  });

  test("a folder containing another game's install is refused", () async {
    final container = await installed();
    final nested = Directory('${installDir.path}/two')..createSync();
    container.read(gamesStateProvider.notifier).markInstalled(2, nested.path);

    await expectLater(uninstall(container), throwsA(isA<UninstallError>()));

    expect(installDir.existsSync(), isTrue);
    expect(
      container.read(gamesStateProvider).getGameStatus(1),
      GameStatus.downloaded,
    );
  });

  test('a failed delete keeps the game installed', () async {
    final container = await installed();
    final link = Link('${root.path}/link')..createSync(installDir.path);
    container.read(gamesStateProvider.notifier).markInstalled(1, link.path);

    await expectLater(uninstall(container), throwsA(isA<UnsafeDeleteError>()));

    expect(installDir.existsSync(), isTrue);
    expect(
      container.read(gamesStateProvider).getGameStatus(1),
      GameStatus.downloaded,
    );
  });

  test('does nothing for a game that is not installed', () async {
    final container = await createContainer();

    await uninstall(container);

    expect(container.read(gamesStateProvider).games, isEmpty);
  });
}
