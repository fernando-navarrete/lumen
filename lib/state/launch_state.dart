import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/app_paths.dart';
import 'package:lumen/common/gog_error.dart';
import 'package:lumen/common/shell_words.dart';
import 'package:lumen/models/launch_target.dart';
import 'package:path/path.dart' as p;

enum LaunchStatus { launching, running, exited, failed }

/// Sentinel default for nullable [RunningGame.copyWith] parameters, so
/// "argument omitted" (keep the existing value) can be distinguished from
/// "argument explicitly passed as `null`" (clear the field) — same pattern
/// as `ActivityTask.copyWith`'s `_unset` in downloads_state.dart.
const _unset = Object();

/// Immutable snapshot of one in-flight/finished game launch, keyed by
/// gameId in [LaunchState.games]. Mirrors [ActivityTask] in
/// downloads_state.dart. Updates go through [copyWith]; [LaunchNotifier] is
/// the only thing that constructs new ones.
class RunningGame {
  final int gameId;
  final LaunchStatus status;
  final int? exitCode;
  final String? error;

  RunningGame({
    required this.gameId,
    this.status = LaunchStatus.launching,
    this.exitCode,
    this.error,
  });

  /// Returns a copy with the given fields replaced. [exitCode] and [error]
  /// default to the [_unset] sentinel rather than `null`, so omitting them
  /// keeps the existing value while passing `null` explicitly clears them.
  RunningGame copyWith({
    LaunchStatus? status,
    Object? exitCode = _unset,
    Object? error = _unset,
  }) {
    return RunningGame(
      gameId: gameId,
      status: status ?? this.status,
      exitCode: identical(exitCode, _unset) ? this.exitCode : exitCode as int?,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }
}

/// Immutable snapshot of in-flight/finished game launches, keyed by gameId.
/// Read-only — mutations go through [LaunchNotifier] via
/// `launchStateProvider.notifier`.
class LaunchState {
  final Map<int, RunningGame> games;

  const LaunchState(this.games);

  const LaunchState.empty() : games = const {};

  RunningGame? gameFor(int gameId) => games[gameId];

  /// Whether [gameId] is currently launching or running — the Play button
  /// should be disabled and show "Running…" while this is true.
  bool isActive(int gameId) {
    final status = games[gameId]?.status;
    return status == LaunchStatus.launching || status == LaunchStatus.running;
  }
}

/// Launches installed games via Proton, following the same recipe as
/// gogdl-cli's `run_game` (see `runner.rs`): a shared Steam compat client
/// directory, a one-time `proton run wineboot` to initialize the prefix,
/// then `proton run <exe> <target args> <user args>` with the game's working
/// directory set to the target's `workingDir` (from GOG's play task) when it
/// has one, else the executable's parent folder. The only environment
/// variables the tool itself sets are `STEAM_COMPAT_CLIENT_INSTALL_PATH` and
/// `STEAM_COMPAT_DATA_PATH` — no WINEPREFIX, no DXVK/winetricks setup. If a
/// launch wrapper is set (e.g. `gamescope -f --`), it is prepended to the
/// `proton run ...` invocation, becoming the process actually spawned —
/// mirroring Steam's launch-option wrappers. The wrapper never applies to
/// the one-time wineboot init, only to the game itself.
///
/// Each launch writes a log to `gameLogPath(gameId)` (the previous one is
/// rotated to `previousGameLogPath`): a header, wineboot's output when it
/// runs, the game's stdout/stderr, and a footer with the exit code. Game
/// output goes only there, never to Lumen's own stdout.
class LaunchNotifier extends Notifier<LaunchState> {
  @override
  LaunchState build() => const LaunchState.empty();

  /// How long to keep reading the game's stdout/stderr after the spawned
  /// process exits. Processes that outlive it (a lingering `wineserver`, or
  /// the game a launcher started) inherit the pipes and can hold them open
  /// indefinitely, so waiting for them to close unbounded could hold off
  /// `exited` for the whole session.
  @visibleForTesting
  Duration pipeDrainGrace = const Duration(seconds: 2);

  /// Commits [next] as the replacement for [current] if [current] is still
  /// the game registered for its gameId — a launch whose entry was replaced
  /// (e.g. a fresh launch started after this one's process already exited)
  /// keeps delivering its exit-code/error callback to an orphaned
  /// closure-local game; this stops that stale callback from clobbering
  /// whatever replaced it. Returns [next] regardless. Mirrors
  /// `DownloadsNotifier._commit` in downloads_state.dart (without the
  /// throttling — launches don't throttle emits).
  RunningGame _commit(RunningGame current, RunningGame next) {
    if (identical(state.games[next.gameId], current)) {
      state = LaunchState({...state.games, next.gameId: next});
    }
    return next;
  }

  /// Launches [gameId] using [protonPath] (the extracted Proton-GE release
  /// directory), the game's [installPath], the resolved [target] (see
  /// `LaunchResolver`; its executable and working dir are relative to
  /// [installPath], and its arguments go before the user's [launchArgs]),
  /// and its Proton [prefixPath]. No-ops if the game is already launching
  /// or running. If [launchWrapper] is non-empty (e.g.
  /// `["gamescope", "-f", "--"]`), it is prepended to the `proton run ...`
  /// invocation so the wrapper becomes the spawned process.
  Future<void> launchGame(
    int gameId, {
    required String protonPath,
    required String installPath,
    required LaunchTarget target,
    required String prefixPath,
    List<String> launchArgs = const [],
    Map<String, String> envVars = const {},
    List<String> launchWrapper = const [],
  }) async {
    debugPrint(
      '[DIAG] launchGame called: gameId=$gameId isActive=${state.isActive(gameId)}',
    );
    if (state.isActive(gameId)) {
      return;
    }

    var game = RunningGame(gameId: gameId, status: LaunchStatus.launching);
    state = LaunchState({...state.games, gameId: game});
    debugPrint('[DIAG] set status=launching, emitted');

    final stopwatch = Stopwatch()..start();
    final log = _GameLog.open(gameId);
    try {
      final compatClientDir = steamCompatClientDir();
      Directory(compatClientDir).createSync(recursive: true);

      final protonBinary = '$protonPath/proton';
      final compatEnv = {
        'STEAM_COMPAT_CLIENT_INSTALL_PATH': compatClientDir,
        'STEAM_COMPAT_DATA_PATH': prefixPath,
      };
      debugPrint('[DIAG] protonBinary=$protonBinary compatEnv=$compatEnv');

      final fullExe = '$installPath/${target.executable}';
      final workingDir = target.workingDir;
      final cwd = workingDir != null
          ? '$installPath/$workingDir'
          : File(fullExe).parent.path;

      // The wrapper (e.g. `gamescope -f --`) becomes the process actually
      // spawned, with the whole Proton invocation as its arguments —
      // mirroring how Steam's launch-option wrappers work.
      final command = [
        protonBinary,
        'run',
        fullExe,
        ...target.arguments,
        ...launchArgs,
      ];
      final wrapped = [...launchWrapper, ...command];

      // The user's env vars are logged verbatim on purpose: they're the
      // user's own settings and the log is a local file, and they're often
      // exactly what explains a broken launch.
      log
        ..writeln('Lumen launch log — ${DateTime.now().toIso8601String()}')
        ..writeln('Game: $gameId')
        ..writeln('Proton: ${p.basename(protonPath)} ($protonPath)')
        ..writeln('Executable source: ${target.source.name}')
        ..writeln('Command: ${joinShellWords(wrapped)}')
        ..writeln('Working directory: $cwd')
        ..writeln('Compat env:');
      for (final entry in compatEnv.entries) {
        log.writeln('  ${entry.key}=${entry.value}');
      }
      log.writeln('User env:${envVars.isEmpty ? ' (none)' : ''}');
      for (final entry in envVars.entries) {
        log.writeln('  ${entry.key}=${entry.value}');
      }

      // Proton creates <prefix>/pfx the first time it runs in a prefix, so
      // its absence signals this prefix hasn't been initialized yet. This
      // init run is never wrapped — it's prefix setup, not the game itself.
      if (!Directory('$prefixPath/pfx').existsSync()) {
        debugPrint('[DIAG] running wineboot init...');
        log.writeln('--- wineboot ---');
        // Include the user's env vars here too (not just compatEnv) — some
        // (e.g. Proton/DXVK feature toggles) only take effect when the
        // prefix is first created, so omitting them here silently drops
        // their effect until the prefix is wiped and recreated. Output is
        // kept as raw bytes, so nothing has to decode it.
        final result = await Process.run(
          protonBinary,
          ['run', 'wineboot'],
          environment: {...envVars, ...compatEnv},
          stdoutEncoding: null,
          stderrEncoding: null,
        );
        log
          ..add(result.stdout as List<int>)
          ..add(result.stderr as List<int>)
          ..writeln('wineboot exited with code ${result.exitCode}');
        debugPrint('[DIAG] wineboot init returned without throwing');
      }

      debugPrint('[DIAG] starting process: ${wrapped.join(' ')} cwd=$cwd');
      log.writeln('--- game ---');
      final process = await Process.start(
        wrapped.first,
        wrapped.sublist(1),
        workingDirectory: cwd,
        environment: {...envVars, ...compatEnv},
        includeParentEnvironment: true,
      );
      debugPrint('[DIAG] process started pid=${process.pid}');
      final pipes = [
        process.stdout.listen(log.add),
        process.stderr.listen(log.add),
      ];
      final drained = Future.wait(pipes.map((sub) => sub.asFuture<void>()));

      game = _commit(game, game.copyWith(status: LaunchStatus.running));

      process.exitCode.then((code) async {
        // The footer and close come before the status commit, so whoever
        // reacts to `exited`/`failed` finds the whole log on disk.
        try {
          await drained.timeout(pipeDrainGrace);
        } on TimeoutException {
          for (final sub in pipes) {
            await sub.cancel();
          }
          log.writeln(
            '(output still open ${pipeDrainGrace.inMilliseconds} ms after '
            'exit; stopped logging it)',
          );
        } catch (e) {
          logGogError(e);
        }
        log.writeln(
          '--- exited with code $code after ${_formatElapsed(stopwatch)} ---',
        );
        await log.close();
        game = _commit(
          game,
          code == 0
              ? game.copyWith(status: LaunchStatus.exited, exitCode: code)
              : game.copyWith(
                  status: LaunchStatus.failed,
                  exitCode: code,
                  error: 'Game exited with code $code',
                ),
        );
      });
    } catch (e) {
      debugPrint('[DIAG] CAUGHT EXCEPTION: $e');
      logGogError(e);
      log.writeln('Launch failed: $e');
      await log.close();
      game = _commit(
        game,
        game.copyWith(status: LaunchStatus.failed, error: e.toString()),
      );
    }
  }
}

/// `h:mm:ss` of [stopwatch]'s elapsed time.
String _formatElapsed(Stopwatch stopwatch) =>
    stopwatch.elapsed.toString().split('.').first;

/// One launch's log file. Logging must never block playing: if the file
/// can't be set up (disk full, permissions, `logs` not a directory), the
/// failure is reported via [logGogError] and every method is a no-op.
class _GameLog {
  _GameLog._(this._sink);

  IOSink? _sink;

  /// Rotates `<gameId>.log` to `<gameId>.previous.log` (one generation,
  /// overwritten) and opens a fresh `<gameId>.log`.
  static _GameLog open(int gameId) {
    try {
      Directory(logsDir()).createSync(recursive: true);
      final file = File(gameLogPath(gameId));
      if (file.existsSync()) {
        file.renameSync(previousGameLogPath(gameId));
      }
      // Created synchronously so a permission error surfaces here, not
      // later on the sink.
      file.createSync();
      final sink = file.openWrite();
      sink.done.catchError((Object e) => logGogError(e));
      return _GameLog._(sink);
    } catch (e) {
      logGogError(e);
      return _GameLog._(null);
    }
  }

  void writeln(String line) => _guard((sink) => sink.writeln(line));

  void add(List<int> bytes) => _guard((sink) => sink.add(bytes));

  void _guard(void Function(IOSink sink) write) {
    final sink = _sink;
    if (sink == null) return;
    try {
      write(sink);
    } catch (e) {
      logGogError(e);
      _sink = null;
    }
  }

  Future<void> close() async {
    final sink = _sink;
    _sink = null;
    if (sink == null) return;
    try {
      await sink.close();
    } catch (e) {
      logGogError(e);
    }
  }
}

final launchStateProvider = NotifierProvider<LaunchNotifier, LaunchState>(
  LaunchNotifier.new,
  name: 'launchStateProvider',
);
