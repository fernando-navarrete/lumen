import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/state/launch_state.dart';

import '../helpers/container.dart';
import '../helpers/temp_data_home.dart';

/// Polls [condition] until it's true or [timeout] elapses, so tests don't
/// need to await the real `process.exitCode` future directly (it resolves
/// via a fire-and-forget `.then()` inside [LaunchNotifier.launchGame], not
/// something the caller awaits).
Future<void> waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('waitFor timed out');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late Directory dataHome;
  late Directory protonDir;
  late Directory prefixDir;
  late Directory installDir;
  late File log;

  setUp(() {
    dataHome = useTempDataHome();
    protonDir = Directory('${dataHome.path}/proton_bin')..createSync();
    prefixDir = Directory('${dataHome.path}/prefix')..createSync();
    installDir = Directory('${dataHome.path}/install')..createSync();
    File('${installDir.path}/game.exe').writeAsStringSync('fake exe');
    log = File('${dataHome.path}/log.txt');
  });

  /// Writes a fake `proton` executable at [protonDir]/proton that logs each
  /// invocation as "$LUMEN_WRAPPED|$STEAM_COMPAT_DATA_PATH|$*" to `$LOG`,
  /// creates "$STEAM_COMPAT_DATA_PATH/pfx" on a `run wineboot` call, and
  /// exits with `$FAKE_EXIT` (default 0).
  void writeFakeProton() {
    final script = File('${protonDir.path}/proton');
    script.writeAsStringSync('''
#!/usr/bin/env bash
echo "\${LUMEN_WRAPPED:-}|\$STEAM_COMPAT_DATA_PATH|\$*" >> "\$LOG"
if [ "\$2" = "wineboot" ]; then
  mkdir -p "\$STEAM_COMPAT_DATA_PATH/pfx"
fi
exit "\${FAKE_EXIT:-0}"
''');
    Process.runSync('chmod', ['+x', script.path]);
  }

  Map<String, String> baseEnv() => {'LOG': log.path};

  group('LaunchNotifier.launchGame', () {
    test('fresh prefix: launching -> running -> exited, wineboot runs first', () async {
      writeFakeProton();
      final container = await createContainer();
      final notifier = container.read(launchStateProvider.notifier);

      final future = notifier.launchGame(
        1,
        protonPath: protonDir.path,
        installPath: installDir.path,
        executable: 'game.exe',
        prefixPath: prefixDir.path,
        envVars: baseEnv(),
      );
      // The synchronous portion of launchGame (before its first `await`)
      // already ran by the time the call returns control here.
      expect(
        container.read(launchStateProvider).gameFor(1)!.status,
        LaunchStatus.launching,
      );

      await future;
      expect(
        container.read(launchStateProvider).gameFor(1)!.status,
        LaunchStatus.running,
      );

      await waitFor(
        () =>
            container.read(launchStateProvider).gameFor(1)!.status !=
            LaunchStatus.running,
      );
      final game = container.read(launchStateProvider).gameFor(1)!;
      expect(game.status, LaunchStatus.exited);
      expect(game.exitCode, 0);

      final lines = log.readAsLinesSync();
      expect(lines, hasLength(2));
      expect(lines[0], contains('run wineboot'));
      expect(lines[1], contains('run ${installDir.path}/game.exe'));
      expect(Directory('${prefixDir.path}/pfx').existsSync(), true);
    });

    test('existing pfx: no wineboot run', () async {
      writeFakeProton();
      Directory('${prefixDir.path}/pfx').createSync();
      final container = await createContainer();
      final notifier = container.read(launchStateProvider.notifier);

      await notifier.launchGame(
        1,
        protonPath: protonDir.path,
        installPath: installDir.path,
        executable: 'game.exe',
        prefixPath: prefixDir.path,
        envVars: baseEnv(),
      );
      await waitFor(
        () =>
            container.read(launchStateProvider).gameFor(1)!.status !=
            LaunchStatus.running,
      );

      final lines = log.readAsLinesSync();
      expect(lines, hasLength(1));
      expect(lines[0], contains('run ${installDir.path}/game.exe'));
    });

    test('non-zero exit code -> failed', () async {
      writeFakeProton();
      Directory('${prefixDir.path}/pfx').createSync();
      final container = await createContainer();
      final notifier = container.read(launchStateProvider.notifier);

      await notifier.launchGame(
        1,
        protonPath: protonDir.path,
        installPath: installDir.path,
        executable: 'game.exe',
        prefixPath: prefixDir.path,
        envVars: {...baseEnv(), 'FAKE_EXIT': '3'},
      );
      await waitFor(
        () =>
            container.read(launchStateProvider).gameFor(1)!.status !=
            LaunchStatus.running,
      );

      final game = container.read(launchStateProvider).gameFor(1)!;
      expect(game.status, LaunchStatus.failed);
      expect(game.exitCode, 3);
      expect(game.error, 'Game exited with code 3');
    });

    test('missing proton binary -> failed with an error', () async {
      // protonDir exists but has no `proton` executable in it.
      final container = await createContainer();
      final notifier = container.read(launchStateProvider.notifier);

      await notifier.launchGame(
        1,
        protonPath: protonDir.path,
        installPath: installDir.path,
        executable: 'game.exe',
        prefixPath: prefixDir.path,
        envVars: baseEnv(),
      );

      final game = container.read(launchStateProvider).gameFor(1)!;
      expect(game.status, LaunchStatus.failed);
      expect(game.error, isNotNull);
    });

    test('launchWrapper applies to the game but not to wineboot init', () async {
      writeFakeProton();
      final container = await createContainer();
      final notifier = container.read(launchStateProvider.notifier);

      await notifier.launchGame(
        1,
        protonPath: protonDir.path,
        installPath: installDir.path,
        executable: 'game.exe',
        prefixPath: prefixDir.path,
        envVars: baseEnv(),
        launchWrapper: const ['env', 'LUMEN_WRAPPED=1'],
      );
      await waitFor(
        () =>
            container.read(launchStateProvider).gameFor(1)!.status !=
            LaunchStatus.running,
      );

      final lines = log.readAsLinesSync();
      expect(lines, hasLength(2));
      expect(lines[0], startsWith('|')); // wineboot: no LUMEN_WRAPPED prefix
      expect(lines[1], startsWith('1|')); // game: LUMEN_WRAPPED=1 set
    });

    test('isActive: a second launchGame call while running is a no-op', () async {
      writeFakeProton();
      Directory('${prefixDir.path}/pfx').createSync();
      final container = await createContainer();
      final notifier = container.read(launchStateProvider.notifier);

      final first = notifier.launchGame(
        1,
        protonPath: protonDir.path,
        installPath: installDir.path,
        executable: 'game.exe',
        prefixPath: prefixDir.path,
        envVars: baseEnv(),
      );
      // Still "launching" (synchronous portion only) — isActive is already
      // true, so a concurrent call right now must no-op too.
      expect(container.read(launchStateProvider).isActive(1), true);
      await notifier.launchGame(
        1,
        protonPath: protonDir.path,
        installPath: installDir.path,
        executable: 'game.exe',
        prefixPath: prefixDir.path,
        envVars: baseEnv(),
      );
      await first;

      await waitFor(
        () =>
            container.read(launchStateProvider).gameFor(1)!.status !=
            LaunchStatus.running,
      );
      // Only one invocation logged — the second call was a no-op.
      expect(log.readAsLinesSync(), hasLength(1));
    });
  });
}
