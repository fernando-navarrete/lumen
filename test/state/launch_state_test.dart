import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/common/app_paths.dart';
import 'package:lumen/models/launch_target.dart';
import 'package:lumen/state/launch_state.dart';
import 'package:path/path.dart' as p;

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

const gameExe = LaunchTarget(
  executable: 'game.exe',
  source: LaunchTargetSource.scan,
);

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
  /// invocation as "$LUMEN_WRAPPED|$STEAM_COMPAT_DATA_PATH|$*|$PWD" to `$LOG`,
  /// echoes "<$2> to-stdout"/"<$2> to-stderr" to its own stdout/stderr,
  /// creates "$STEAM_COMPAT_DATA_PATH/pfx" and exits with `$WINEBOOT_EXIT`
  /// (default 0) on a `run wineboot` call, leaves a background `sleep`
  /// holding its stdout/stderr open if `$HOLD_PIPE` is set, and otherwise
  /// exits with `$FAKE_EXIT` (default 0). If `$PIDFILE` is set, a game run
  /// instead writes its pid there and `exec`s a long `sleep`, so it runs
  /// until killed and the killed pid is the spawned process itself.
  void writeFakeProton() {
    final script = File('${protonDir.path}/proton');
    script.writeAsStringSync('''
#!/usr/bin/env bash
echo "\${LUMEN_WRAPPED:-}|\$STEAM_COMPAT_DATA_PATH|\$*|\$PWD" >> "\$LOG"
echo "<\$2> to-stdout"
echo "<\$2> to-stderr" >&2
if [ "\$2" = "wineboot" ]; then
  mkdir -p "\$STEAM_COMPAT_DATA_PATH/pfx"
  exit "\${WINEBOOT_EXIT:-0}"
fi
if [ -n "\${PIDFILE:-}" ]; then
  echo \$\$ > "\$PIDFILE"
  exec sleep 30
fi
if [ -n "\${HOLD_PIPE:-}" ]; then
  sleep 3 &
fi
exit "\${FAKE_EXIT:-0}"
''');
    Process.runSync('chmod', ['+x', script.path]);
  }

  Map<String, String> baseEnv() => {'LOG': log.path};

  group('LaunchNotifier.launchGame', () {
    test(
      'fresh prefix: launching -> running -> exited, wineboot runs first',
      () async {
        writeFakeProton();
        final container = await createContainer();
        final notifier = container.read(launchStateProvider.notifier);

        final future = notifier.launchGame(
          1,
          protonPath: protonDir.path,
          installPath: installDir.path,
          target: gameExe,
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
      },
    );

    test('existing pfx: no wineboot run', () async {
      writeFakeProton();
      Directory('${prefixDir.path}/pfx').createSync();
      final container = await createContainer();
      final notifier = container.read(launchStateProvider.notifier);

      await notifier.launchGame(
        1,
        protonPath: protonDir.path,
        installPath: installDir.path,
        target: gameExe,
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

    test('non-zero exit right after spawn -> failed', () async {
      writeFakeProton();
      Directory('${prefixDir.path}/pfx').createSync();
      final container = await createContainer();
      final notifier = container.read(launchStateProvider.notifier);

      await notifier.launchGame(
        1,
        protonPath: protonDir.path,
        installPath: installDir.path,
        target: gameExe,
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
      expect(game.error, 'The game exited immediately (code 3)');
    });

    test('non-zero exit after the window -> exited', () async {
      writeFakeProton();
      Directory('${prefixDir.path}/pfx').createSync();
      final container = await createContainer();
      final notifier = container.read(launchStateProvider.notifier)
        ..immediateExitWindow = Duration.zero;

      await notifier.launchGame(
        1,
        protonPath: protonDir.path,
        installPath: installDir.path,
        target: gameExe,
        prefixPath: prefixDir.path,
        envVars: {...baseEnv(), 'FAKE_EXIT': '3'},
      );
      await waitFor(
        () =>
            container.read(launchStateProvider).gameFor(1)!.status !=
            LaunchStatus.running,
      );

      final game = container.read(launchStateProvider).gameFor(1)!;
      expect(game.status, LaunchStatus.exited);
      expect(game.exitCode, 3);
      expect(game.error, null);
    });

    test(
      'wineboot failure -> failed, game never spawned, pfx removed, next '
      'launch retries init',
      () async {
        writeFakeProton();
        final container = await createContainer();
        final notifier = container.read(launchStateProvider.notifier);

        await notifier.launchGame(
          1,
          protonPath: protonDir.path,
          installPath: installDir.path,
          target: gameExe,
          prefixPath: prefixDir.path,
          envVars: {...baseEnv(), 'WINEBOOT_EXIT': '1'},
        );

        final game = container.read(launchStateProvider).gameFor(1)!;
        expect(game.status, LaunchStatus.failed);
        expect(
          game.error,
          'Prefix initialization failed (exit 1) — see the log',
        );
        expect(log.readAsLinesSync(), hasLength(1));
        expect(log.readAsLinesSync()[0], contains('run wineboot'));
        expect(Directory('${prefixDir.path}/pfx').existsSync(), false);

        // The next launch sees no pfx and retries init.
        await notifier.launchGame(
          1,
          protonPath: protonDir.path,
          installPath: installDir.path,
          target: gameExe,
          prefixPath: prefixDir.path,
          envVars: baseEnv(),
        );
        await waitFor(
          () =>
              container.read(launchStateProvider).gameFor(1)!.status !=
              LaunchStatus.running,
        );

        // The fake proton's own invocation log ($LOG) isn't rotated between
        // launches like the real game log is, so it now holds both the
        // first (failed) wineboot call and the second launch's wineboot +
        // game calls.
        final lines = log.readAsLinesSync();
        expect(lines, hasLength(3));
        expect(lines[1], contains('run wineboot'));
        expect(lines[2], contains('run ${installDir.path}/game.exe'));
        final second = container.read(launchStateProvider).gameFor(1)!;
        expect(second.status, LaunchStatus.exited);
        expect(Directory('${prefixDir.path}/pfx').existsSync(), true);
      },
    );

    test(
      'missing proton binary -> failed with an error, no log touched',
      () async {
        // protonDir exists but has no `proton` executable in it.
        final previousLog = File(gameLogPath(1))
          ..createSync(recursive: true)
          ..writeAsStringSync('previous run');
        final container = await createContainer();
        final notifier = container.read(launchStateProvider.notifier);

        await notifier.launchGame(
          1,
          protonPath: protonDir.path,
          installPath: installDir.path,
          target: gameExe,
          prefixPath: prefixDir.path,
          envVars: baseEnv(),
        );

        final game = container.read(launchStateProvider).gameFor(1)!;
        expect(game.status, LaunchStatus.failed);
        expect(
          game.error,
          'Proton-GE ${p.basename(protonDir.path)} is missing its proton '
          'script at ${protonDir.path}/proton — reinstall it in Settings',
        );
        // No log was opened for this launch, so the previous one wasn't
        // rotated away.
        expect(previousLog.readAsStringSync(), 'previous run');
        expect(File(previousGameLogPath(1)).existsSync(), false);
      },
    );

    test('non-executable proton binary -> failed with an error', () async {
      // Written but never chmod +x'd.
      File('${protonDir.path}/proton').writeAsStringSync('#!/usr/bin/env bash\nexit 0\n');
      final container = await createContainer();
      final notifier = container.read(launchStateProvider.notifier);

      await notifier.launchGame(
        1,
        protonPath: protonDir.path,
        installPath: installDir.path,
        target: gameExe,
        prefixPath: prefixDir.path,
        envVars: baseEnv(),
      );

      final game = container.read(launchStateProvider).gameFor(1)!;
      expect(game.status, LaunchStatus.failed);
      expect(
        game.error,
        'Proton-GE ${p.basename(protonDir.path)} is missing its proton '
        'script at ${protonDir.path}/proton — reinstall it in Settings',
      );
      expect(Directory('${prefixDir.path}/pfx').existsSync(), false);
    });

    test('launchWrapper not found on PATH -> failed with an error', () async {
      writeFakeProton();
      final emptyPathDir = Directory('${dataHome.path}/empty_path')
        ..createSync();
      final container = await createContainer();
      final notifier = container.read(launchStateProvider.notifier);

      await notifier.launchGame(
        1,
        protonPath: protonDir.path,
        installPath: installDir.path,
        target: gameExe,
        prefixPath: prefixDir.path,
        envVars: {...baseEnv(), 'PATH': emptyPathDir.path},
        launchWrapper: const ['gamescope', '-f', '--'],
      );

      final game = container.read(launchStateProvider).gameFor(1)!;
      expect(game.status, LaunchStatus.failed);
      expect(game.error, 'Launch wrapper "gamescope" not found on PATH');
      expect(log.existsSync(), false); // proton was never invoked
      expect(Directory('${prefixDir.path}/pfx').existsSync(), false);
    });

    test(
      'launchWrapper not found by path -> failed with an error',
      () async {
        writeFakeProton();
        final container = await createContainer();
        final notifier = container.read(launchStateProvider.notifier);

        await notifier.launchGame(
          1,
          protonPath: protonDir.path,
          installPath: installDir.path,
          target: gameExe,
          prefixPath: prefixDir.path,
          envVars: baseEnv(),
          launchWrapper: const ['/nonexistent/wrap'],
        );

        final game = container.read(launchStateProvider).gameFor(1)!;
        expect(game.status, LaunchStatus.failed);
        expect(
          game.error,
          'Launch wrapper "/nonexistent/wrap" not found or not executable',
        );
      },
    );

    test('a present launchWrapper resolved via PATH passes', () async {
      writeFakeProton();
      final wrapperDir = Directory('${dataHome.path}/wrapper_bin')
        ..createSync();
      final wrapperScript = File('${wrapperDir.path}/wrap')
        ..writeAsStringSync('#!/usr/bin/env bash\nexec "\$@"\n');
      Process.runSync('chmod', ['+x', wrapperScript.path]);
      final container = await createContainer();
      final notifier = container.read(launchStateProvider.notifier);

      await notifier.launchGame(
        1,
        protonPath: protonDir.path,
        installPath: installDir.path,
        target: gameExe,
        prefixPath: prefixDir.path,
        envVars: {
          ...baseEnv(),
          'PATH': '${wrapperDir.path}:${Platform.environment['PATH']}',
        },
        launchWrapper: const ['wrap'],
      );
      await waitFor(
        () =>
            container.read(launchStateProvider).gameFor(1)!.status !=
            LaunchStatus.running,
      );

      final game = container.read(launchStateProvider).gameFor(1)!;
      expect(game.status, LaunchStatus.exited);
    });

    test(
      'launchWrapper applies to the game but not to wineboot init',
      () async {
        writeFakeProton();
        final container = await createContainer();
        final notifier = container.read(launchStateProvider.notifier);

        await notifier.launchGame(
          1,
          protonPath: protonDir.path,
          installPath: installDir.path,
          target: gameExe,
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
      },
    );

    test("cwd defaults to the executable's parent", () async {
      writeFakeProton();
      Directory('${prefixDir.path}/pfx').createSync();
      File('${installDir.path}/bin/x64/game.exe')
        ..createSync(recursive: true)
        ..writeAsStringSync('fake exe');
      final container = await createContainer();
      final notifier = container.read(launchStateProvider.notifier);

      await notifier.launchGame(
        1,
        protonPath: protonDir.path,
        installPath: installDir.path,
        target: const LaunchTarget(
          executable: 'bin/x64/game.exe',
          source: LaunchTargetSource.scan,
        ),
        prefixPath: prefixDir.path,
        envVars: baseEnv(),
      );
      await waitFor(
        () =>
            container.read(launchStateProvider).gameFor(1)!.status !=
            LaunchStatus.running,
      );

      final line = log.readAsLinesSync().single;
      expect(line.split('|').last, '${installDir.path}/bin/x64');
    });

    test("the target's workingDir sets cwd, and its arguments go before the "
        "user's", () async {
      writeFakeProton();
      Directory('${prefixDir.path}/pfx').createSync();
      File('${installDir.path}/bin/x64/game.exe')
        ..createSync(recursive: true)
        ..writeAsStringSync('fake exe');
      final container = await createContainer();
      final notifier = container.read(launchStateProvider.notifier);

      await notifier.launchGame(
        1,
        protonPath: protonDir.path,
        installPath: installDir.path,
        target: const LaunchTarget(
          executable: 'bin/x64/game.exe',
          workingDir: 'bin',
          arguments: ['-task-arg'],
          source: LaunchTargetSource.gogMetadata,
        ),
        prefixPath: prefixDir.path,
        launchArgs: const ['-user-arg'],
        envVars: baseEnv(),
      );
      await waitFor(
        () =>
            container.read(launchStateProvider).gameFor(1)!.status !=
            LaunchStatus.running,
      );

      final line = log.readAsLinesSync().single;
      expect(
        line,
        contains('run ${installDir.path}/bin/x64/game.exe -task-arg -user-arg'),
      );
      expect(line.split('|').last, '${installDir.path}/bin');
    });

    test(
      'isActive: a second launchGame call while running is a no-op',
      () async {
        writeFakeProton();
        Directory('${prefixDir.path}/pfx').createSync();
        final container = await createContainer();
        final notifier = container.read(launchStateProvider.notifier);

        final first = notifier.launchGame(
          1,
          protonPath: protonDir.path,
          installPath: installDir.path,
          target: gameExe,
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
          target: gameExe,
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
      },
    );
  });

  group('LaunchNotifier — immutability (Phase 6)', () {
    test(
      'an event produces a new game; the old snapshot keeps its old values',
      () async {
        writeFakeProton();
        final container = await createContainer();
        final notifier = container.read(launchStateProvider.notifier);

        final future = notifier.launchGame(
          1,
          protonPath: protonDir.path,
          installPath: installDir.path,
          target: gameExe,
          prefixPath: prefixDir.path,
          envVars: baseEnv(),
        );
        // The synchronous portion of launchGame (before its first `await`)
        // already ran by the time the call returns control here.
        final launching = container.read(launchStateProvider).gameFor(1)!;
        expect(launching.status, LaunchStatus.launching);

        await future;
        final running = container.read(launchStateProvider).gameFor(1)!;

        expect(identical(launching, running), isFalse);
        expect(launching.status, LaunchStatus.launching);
        expect(running.status, LaunchStatus.running);

        // Wait for the process to actually exit before the test (and its
        // container) tears down — otherwise the fire-and-forget
        // `process.exitCode.then` callback runs after disposal and throws.
        await waitFor(
          () =>
              container.read(launchStateProvider).gameFor(1)!.status !=
              LaunchStatus.running,
        );
      },
    );

    test(
      'the launching -> failed transition is visible to a listener (drives the '
      'launch-failure snackbar in game_action_buttons.dart)',
      () async {
        writeFakeProton();
        Directory('${prefixDir.path}/pfx').createSync();
        final container = await createContainer();
        final notifier = container.read(launchStateProvider.notifier);

        final seen = <LaunchStatus?>[];
        container.listen<LaunchState>(launchStateProvider, (previous, next) {
          seen.add(next.gameFor(1)?.status);
        });

        await notifier.launchGame(
          1,
          protonPath: protonDir.path,
          installPath: installDir.path,
          target: gameExe,
          prefixPath: prefixDir.path,
          envVars: {...baseEnv(), 'FAKE_EXIT': '3'},
        );
        await waitFor(
          () =>
              container.read(launchStateProvider).gameFor(1)!.status !=
              LaunchStatus.running,
        );

        // Each transition is its own event with a genuinely new object, so a
        // listener sees `running` before `failed` rather than jumping
        // straight from `launching` to `failed` on a shared instance.
        expect(seen, [
          LaunchStatus.launching,
          LaunchStatus.running,
          LaunchStatus.failed,
        ]);
      },
    );
  });
  group('LaunchNotifier — game log (Phase 5)', () {
    File gameLog() => File(gameLogPath(1));

    /// Launches game 1 with [gameExe] and returns it once it has settled
    /// (neither launching nor running).
    Future<RunningGame> launchAndSettle(
      ProviderContainer container, {
      Map<String, String> env = const {},
    }) async {
      await container
          .read(launchStateProvider.notifier)
          .launchGame(
            1,
            protonPath: protonDir.path,
            installPath: installDir.path,
            target: gameExe,
            prefixPath: prefixDir.path,
            launchArgs: const ['-user-arg'],
            envVars: {...baseEnv(), ...env},
          );
      await waitFor(() {
        final status = container.read(launchStateProvider).gameFor(1)!.status;
        return status != LaunchStatus.launching &&
            status != LaunchStatus.running;
      });
      return container.read(launchStateProvider).gameFor(1)!;
    }

    test('has the header, the wineboot section, the game output and the '
        'footer, complete as soon as the game exits', () async {
      writeFakeProton();
      final container = await createContainer();

      final game = await launchAndSettle(container);
      expect(game.status, LaunchStatus.exited);

      // Read right at the status change: the log must already be closed.
      final text = gameLog().readAsStringSync();
      expect(text, contains('Proton: proton_bin (${protonDir.path})'));
      expect(text, contains('Executable source: scan'));
      expect(
        text,
        contains(
          'Command: ${protonDir.path}/proton run '
          '${installDir.path}/game.exe -user-arg',
        ),
      );
      expect(text, contains('Working directory: ${installDir.path}\n'));
      expect(text, contains('  STEAM_COMPAT_DATA_PATH=${prefixDir.path}\n'));
      expect(text, contains('  LOG=${log.path}\n'));
      expect(text, contains('--- wineboot ---\n'));
      expect(text, contains('<wineboot> to-stdout\n'));
      expect(text, contains('<wineboot> to-stderr\n'));
      expect(text, contains('wineboot exited with code 0\n'));
      expect(text, matches(RegExp(r'--- game ---\nPid: \d+\n')));
      expect(text, contains('<${installDir.path}/game.exe> to-stdout\n'));
      expect(text, contains('<${installDir.path}/game.exe> to-stderr\n'));
      expect(
        text,
        matches(RegExp(r'--- exited with code 0 after \d+:\d\d:\d\d ---\n$')),
      );
      expect(
        text.indexOf('--- wineboot ---'),
        lessThan(text.indexOf('--- game ---')),
      );
    });

    test('existing pfx: no wineboot section', () async {
      writeFakeProton();
      Directory('${prefixDir.path}/pfx').createSync();
      final container = await createContainer();

      await launchAndSettle(container);

      final text = gameLog().readAsStringSync();
      expect(text, isNot(contains('wineboot')));
      expect(text, contains('--- game ---\n'));
    });

    test('a wineboot failure logs the exit code and the failure, with no '
        'game section', () async {
      writeFakeProton();
      final container = await createContainer();

      final game = await launchAndSettle(container, env: {
        'WINEBOOT_EXIT': '1',
      });
      expect(game.status, LaunchStatus.failed);

      final text = gameLog().readAsStringSync();
      expect(text, contains('--- wineboot ---\n'));
      expect(text, contains('wineboot exited with code 1\n'));
      expect(text, contains('Removed half-initialized pfx.\n'));
      expect(
        text,
        contains('Launch failed: prefix initialization failed (exit 1)\n'),
      );
      expect(text, isNot(contains('--- game ---')));
    });

    test('a non-zero exit is in the footer', () async {
      writeFakeProton();
      Directory('${prefixDir.path}/pfx').createSync();
      final container = await createContainer();

      final game = await launchAndSettle(container, env: {'FAKE_EXIT': '3'});

      expect(game.status, LaunchStatus.failed);
      expect(gameLog().readAsStringSync(), contains('exited with code 3'));
    });

    test('a second launch rotates the first log to .previous.log', () async {
      writeFakeProton();
      final container = await createContainer();

      await launchAndSettle(container);
      final first = gameLog().readAsStringSync();
      await launchAndSettle(container);

      expect(File(previousGameLogPath(1)).readAsStringSync(), first);
      final second = gameLog().readAsStringSync();
      // The second launch found pfx already there, so no wineboot.
      expect(first, contains('--- wineboot ---'));
      expect(second, isNot(contains('--- wineboot ---')));
    });

    test('an unwritable logs dir still launches', () async {
      writeFakeProton();
      Directory('${prefixDir.path}/pfx').createSync();
      File(logsDir())
        ..createSync(recursive: true)
        ..writeAsStringSync('not a directory');
      final container = await createContainer();

      final game = await launchAndSettle(container);

      expect(game.status, LaunchStatus.exited);
      expect(log.readAsLinesSync(), hasLength(1));
    });

    test('output held open past the exit is cut off after the grace '
        'period', () async {
      writeFakeProton();
      Directory('${prefixDir.path}/pfx').createSync();
      final container = await createContainer();
      container.read(launchStateProvider.notifier).pipeDrainGrace =
          const Duration(milliseconds: 100);

      final stopwatch = Stopwatch()..start();
      final game = await launchAndSettle(container, env: {'HOLD_PIPE': '1'});

      // The background sleep holds the pipes for 3 s.
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(game.status, LaunchStatus.exited);
      final text = gameLog().readAsStringSync();
      expect(text, contains('stopped logging it'));
      expect(text, contains('--- exited with code 0 after'));
    });

    test('a launch that fails to spawn logs why', () async {
      // A valid, executable proton passes the pre-spawn validation, but a
      // working directory that doesn't exist still fails Process.start
      // itself, which is what this test is after.
      writeFakeProton();
      final container = await createContainer();

      await container
          .read(launchStateProvider.notifier)
          .launchGame(
            1,
            protonPath: protonDir.path,
            installPath: installDir.path,
            target: const LaunchTarget(
              executable: 'game.exe',
              workingDir: 'missing-dir',
              source: LaunchTargetSource.scan,
            ),
            prefixPath: prefixDir.path,
            envVars: baseEnv(),
          );

      final game = container.read(launchStateProvider).gameFor(1)!;
      expect(game.status, LaunchStatus.failed);
      expect(gameLog().readAsStringSync(), contains('Launch failed: '));
    });
  });

  group('LaunchNotifier.stopGame (Phase 6)', () {
    late File pidFile;
    late File wineserverLog;

    setUp(() {
      pidFile = File('${dataHome.path}/game.pid');
      wineserverLog = File('${dataHome.path}/wineserver.log');
    });

    /// Writes a fake `wineserver` in the release layout that logs
    /// "$*|$WINEPREFIX" and, if [kills], SIGTERMs the fake game, then sleeps
    /// [linger] and exits with [exitCode]. The test's env vars never reach
    /// wineserver, so the paths are baked in.
    void writeFakeWineserver({
      bool kills = true,
      String linger = '0',
      int exitCode = 0,
    }) {
      final script = File('${protonDir.path}/files/bin/wineserver')
        ..createSync(recursive: true);
      script.writeAsStringSync('''
#!/usr/bin/env bash
echo "\$*|\$WINEPREFIX" >> "${wineserverLog.path}"
${kills ? 'kill -TERM "\$(cat "${pidFile.path}")"' : ''}
sleep $linger
exit $exitCode
''');
      Process.runSync('chmod', ['+x', script.path]);
    }

    LaunchStatus? statusOf(ProviderContainer container) =>
        container.read(launchStateProvider).gameFor(1)?.status;

    /// Launches game 1 as a long-running fake and waits until its pid file
    /// is written.
    Future<void> launchRunning(ProviderContainer container) async {
      if (pidFile.existsSync()) pidFile.deleteSync();
      await container
          .read(launchStateProvider.notifier)
          .launchGame(
            1,
            protonPath: protonDir.path,
            installPath: installDir.path,
            target: gameExe,
            prefixPath: prefixDir.path,
            envVars: {...baseEnv(), 'PIDFILE': pidFile.path},
          );
      expect(statusOf(container), LaunchStatus.running);
      await waitFor(
        () => pidFile.existsSync() && pidFile.readAsStringSync().isNotEmpty,
      );
    }

    Future<void> waitSettled(ProviderContainer container) => waitFor(() {
      final status = statusOf(container);
      return status == LaunchStatus.exited || status == LaunchStatus.failed;
    });

    setUp(() {
      writeFakeProton();
      Directory('${prefixDir.path}/pfx').createSync();
    });

    test('runs wineserver -k on the prefix; a killed game ends exited, not '
        'failed', () async {
      writeFakeWineserver();
      final container = await createContainer();
      final seen = <LaunchStatus?>[];
      container.listen<LaunchState>(
        launchStateProvider,
        (_, next) => seen.add(next.gameFor(1)?.status),
      );
      await launchRunning(container);

      await container.read(launchStateProvider.notifier).stopGame(1);
      await waitSettled(container);

      expect(
        wineserverLog.readAsLinesSync().single,
        '-k|${prefixDir.path}/pfx',
      );
      final game = container.read(launchStateProvider).gameFor(1)!;
      expect(game.status, LaunchStatus.exited);
      expect(game.exitCode, isNot(0));
      expect(game.error, isNull);
      expect(seen, [
        LaunchStatus.launching,
        LaunchStatus.running,
        LaunchStatus.stopping,
        LaunchStatus.exited,
      ]);
      final text = File(gameLogPath(1)).readAsStringSync();
      expect(text, contains('--- stop requested ---'));
      expect(text, contains('--- stopped by user; exited with code'));
      expect(text, isNot(contains('SIGTERM')));
    });

    test('a game still alive after the grace period is SIGTERMed', () async {
      writeFakeWineserver(kills: false);
      final container = await createContainer();
      container.read(launchStateProvider.notifier).stopGrace = const Duration(
        milliseconds: 100,
      );
      await launchRunning(container);

      await container.read(launchStateProvider.notifier).stopGame(1);
      await waitSettled(container);

      expect(wineserverLog.readAsLinesSync(), hasLength(1));
      expect(statusOf(container), LaunchStatus.exited);
      final text = File(gameLogPath(1)).readAsStringSync();
      expect(text, contains('sending SIGTERM'));
      expect(text, isNot(contains('SIGKILL')));
    });

    test('a missing wineserver goes straight to SIGTERM', () async {
      final container = await createContainer();
      // Would take 5 s if the grace period weren't skipped.
      final stopwatch = Stopwatch()..start();
      await launchRunning(container);

      await container.read(launchStateProvider.notifier).stopGame(1);
      await waitSettled(container);

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
      expect(statusOf(container), LaunchStatus.exited);
      final text = File(gameLogPath(1)).readAsStringSync();
      expect(text, contains('wineserver -k failed: '));
      expect(text, contains('sending SIGTERM'));
    });

    test('is a no-op for a game that is not running', () async {
      writeFakeWineserver();
      final container = await createContainer();
      final notifier = container.read(launchStateProvider.notifier);

      await notifier.stopGame(1);
      expect(statusOf(container), isNull);

      await notifier.launchGame(
        1,
        protonPath: protonDir.path,
        installPath: installDir.path,
        target: gameExe,
        prefixPath: prefixDir.path,
        envVars: baseEnv(),
      );
      await waitSettled(container);
      final exited = container.read(launchStateProvider).gameFor(1);
      await notifier.stopGame(1);

      expect(
        identical(container.read(launchStateProvider).gameFor(1), exited),
        isTrue,
      );
      expect(wineserverLog.existsSync(), isFalse);
    });

    test('Play while stopping is ignored', () async {
      writeFakeWineserver(kills: false);
      final container = await createContainer();
      final notifier = container.read(launchStateProvider.notifier)
        ..stopGrace = const Duration(milliseconds: 300);
      await launchRunning(container);

      final stop = notifier.stopGame(1);
      expect(statusOf(container), LaunchStatus.stopping);
      await notifier.launchGame(
        1,
        protonPath: protonDir.path,
        installPath: installDir.path,
        target: gameExe,
        prefixPath: prefixDir.path,
        envVars: baseEnv(),
      );
      expect(statusOf(container), LaunchStatus.stopping);
      await stop;
      await waitSettled(container);

      expect(log.readAsLinesSync(), hasLength(1));
      expect(statusOf(container), LaunchStatus.exited);
    });

    test("a stop's late escalation can't touch a relaunched game", () async {
      // wineserver kills game 1 but lingers, then reports failure, so the
      // relaunch happens while that stop is still in flight, and its SIGTERM
      // escalation runs after the new game is already running.
      writeFakeWineserver(linger: '1', exitCode: 1);
      final container = await createContainer();
      final notifier = container.read(launchStateProvider.notifier)
        ..killGrace = const Duration(milliseconds: 300);
      await launchRunning(container);
      final firstPid = pidFile.readAsStringSync().trim();

      final stop = notifier.stopGame(1);
      await waitSettled(container);
      await launchRunning(container);
      final second = container.read(launchStateProvider).gameFor(1)!;
      final secondPid = pidFile.readAsStringSync().trim();
      expect(secondPid, isNot(firstPid));
      await stop;
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // The first launch's log was closed at its exit, so the late SIGTERM
      // note goes nowhere — and certainly not into the second game's log.
      expect(File(gameLogPath(1)).readAsStringSync(), isNot(contains('stop')));
      // kill -0 via bash's builtin: the CI image has no standalone `kill`.
      expect(
        Process.runSync('bash', ['-c', 'kill -0 $secondPid']).exitCode,
        0,
      );

      expect(
        identical(container.read(launchStateProvider).gameFor(1), second),
        isTrue,
      );
      expect(second.status, LaunchStatus.running);

      writeFakeWineserver();
      await notifier.stopGame(1);
      await waitSettled(container);
    });
  });
}
