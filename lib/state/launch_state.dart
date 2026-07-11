import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl2_flutter/common/app_paths.dart';

enum LaunchStatus { launching, running, exited, failed }

/// In-flight/finished launch state for one game, keyed by gameId in
/// [LaunchState.games]. Mirrors [ActivityTask] in downloads_state.dart.
class RunningGame {
  final int gameId;
  LaunchStatus status;
  int? exitCode;
  String? error;

  RunningGame({
    required this.gameId,
    this.status = LaunchStatus.launching,
    this.exitCode,
    this.error,
  });
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
/// `STEAM_COMPAT_DATA_PATH` — no WINEPREFIX, no DXVK/winetricks setup.
class LaunchNotifier extends Notifier<LaunchState> {
  @override
  LaunchState build() => const LaunchState.empty();

  void _emit() {
    state = LaunchState({...state.games});
  }

  /// Launches [gameId] using [protonPath] (the extracted Proton-GE release
  /// directory), the game's [installPath] and [executable] (relative to
  /// it), and its Proton [prefixPath]. No-ops if the game is already
  /// launching or running.
  Future<void> launchGame(
    int gameId, {
    required String protonPath,
    required String installPath,
    required String executable,
    required String prefixPath,
    List<String> launchArgs = const [],
    Map<String, String> envVars = const {},
  }) async {
    debugPrint('[DIAG] launchGame called: gameId=$gameId isActive=${state.isActive(gameId)}');
    if (state.isActive(gameId)) {
      return;
    }

    final game = RunningGame(gameId: gameId, status: LaunchStatus.launching);
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
      // its absence signals this prefix hasn't been initialized yet.
      if (!Directory('$prefixPath/pfx').existsSync()) {
        debugPrint('[DIAG] running wineboot init...');
        await Process.run(
          protonBinary,
          ['run', 'wineboot'],
          environment: compatEnv,
        );
        debugPrint('[DIAG] wineboot init returned without throwing');
      }

      final fullExe = '$installPath/$executable';
      final cwd = File(fullExe).parent.path;
      debugPrint('[DIAG] starting process: $protonBinary run $fullExe cwd=$cwd');

      final process = await Process.start(
        protonBinary,
        ['run', fullExe, ...launchArgs],
        workingDirectory: cwd,
        environment: {...envVars, ...compatEnv},
        includeParentEnvironment: true,
      );
      debugPrint('[DIAG] process started pid=${process.pid}');

      game.status = LaunchStatus.running;
      _emit();

      process.exitCode.then((code) {
        game.exitCode = code;
        if (code == 0) {
          game.status = LaunchStatus.exited;
        } else {
          game.status = LaunchStatus.failed;
          game.error = 'Game exited with code $code';
        }
        _emit();
      });
    } catch (e) {
      debugPrint('[DIAG] CAUGHT EXCEPTION: $e');
      if (kDebugMode) {
        print(e);
      }
      game.status = LaunchStatus.failed;
      game.error = e.toString();
      _emit();
    }
  }
}

final launchStateProvider = NotifierProvider<LaunchNotifier, LaunchState>(
  LaunchNotifier.new,
  name: 'launchStateProvider',
);
