import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/app_paths.dart';
import 'package:lumen/common/gog_error.dart';

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
/// then `proton run <exe> <args>` with the game's working directory set to
/// the executable's parent folder. The only environment variables the tool
/// itself sets are `STEAM_COMPAT_CLIENT_INSTALL_PATH` and
/// `STEAM_COMPAT_DATA_PATH` — no WINEPREFIX, no DXVK/winetricks setup. If a
/// launch wrapper is set (e.g. `gamescope -f --`), it is prepended to the
/// `proton run ...` invocation, becoming the process actually spawned —
/// mirroring Steam's launch-option wrappers. The wrapper never applies to
/// the one-time wineboot init, only to the game itself.
class LaunchNotifier extends Notifier<LaunchState> {
  @override
  LaunchState build() => const LaunchState.empty();

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
  /// directory), the game's [installPath] and [executable] (relative to
  /// it), and its Proton [prefixPath]. No-ops if the game is already
  /// launching or running. If [launchWrapper] is non-empty (e.g.
  /// `["gamescope", "-f", "--"]`), it is prepended to the `proton run ...`
  /// invocation so the wrapper becomes the spawned process.
  Future<void> launchGame(
    int gameId, {
    required String protonPath,
    required String installPath,
    required String executable,
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

    try {
      final compatClientDir = steamCompatClientDir();
      Directory(compatClientDir).createSync(recursive: true);

      final protonBinary = '$protonPath/proton';
      final compatEnv = {
        'STEAM_COMPAT_CLIENT_INSTALL_PATH': compatClientDir,
        'STEAM_COMPAT_DATA_PATH': prefixPath,
      };
      debugPrint('[DIAG] protonBinary=$protonBinary compatEnv=$compatEnv');

      // Proton creates <prefix>/pfx the first time it runs in a prefix, so
      // its absence signals this prefix hasn't been initialized yet. This
      // init run is never wrapped — it's prefix setup, not the game itself.
      if (!Directory('$prefixPath/pfx').existsSync()) {
        debugPrint('[DIAG] running wineboot init...');
        // Include the user's env vars here too (not just compatEnv) — some
        // (e.g. Proton/DXVK feature toggles) only take effect when the
        // prefix is first created, so omitting them here silently drops
        // their effect until the prefix is wiped and recreated.
        await Process.run(
          protonBinary,
          ['run', 'wineboot'],
          environment: {...envVars, ...compatEnv},
        );
        debugPrint('[DIAG] wineboot init returned without throwing');
      }

      final fullExe = '$installPath/$executable';
      final cwd = File(fullExe).parent.path;

      // The wrapper (e.g. `gamescope -f --`) becomes the process actually
      // spawned, with the whole Proton invocation as its arguments —
      // mirroring how Steam's launch-option wrappers work.
      final command = [protonBinary, 'run', fullExe, ...launchArgs];
      final wrapped = [...launchWrapper, ...command];
      debugPrint('[DIAG] starting process: ${wrapped.join(' ')} cwd=$cwd');

      final process = await Process.start(
        wrapped.first,
        wrapped.sublist(1),
        workingDirectory: cwd,
        environment: {...envVars, ...compatEnv},
        includeParentEnvironment: true,
      );
      debugPrint('[DIAG] process started pid=${process.pid}');
      process.stdout.listen(stdout.add);
      process.stderr.listen(stderr.add);

      game = _commit(game, game.copyWith(status: LaunchStatus.running));

      process.exitCode.then((code) {
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
      game = _commit(
        game,
        game.copyWith(status: LaunchStatus.failed, error: e.toString()),
      );
    }
  }
}

final launchStateProvider = NotifierProvider<LaunchNotifier, LaunchState>(
  LaunchNotifier.new,
  name: 'launchStateProvider',
);
