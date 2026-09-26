import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/app_paths.dart';
import 'package:lumen/common/safe_delete.dart';
import 'package:lumen/state/downloads_state.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/launch_state.dart';
import 'package:lumen/state/saves_state.dart';

/// Thrown by [Uninstaller.uninstallGame] when it refuses to start; [toString]
/// is the user-facing message.
class UninstallError implements Exception {
  final String message;

  const UninstallError(this.message);

  @override
  String toString() => message;
}

/// Uninstalls installed games. Stateless: everything it changes lives in
/// [GamesNotifier] and [DownloadsNotifier].
class Uninstaller {
  final Ref _ref;

  Uninstaller(this._ref);

  /// Uninstalls [gameId]: stops any running job, optionally deletes the
  /// install folder ([deleteFiles]) and the Lumen-owned Wine prefix with the
  /// game's logs ([deletePrefix]), then removes the game's whole config entry
  /// so a later install starts fresh.
  ///
  /// Refuses while the game is running or a save sync is in flight, and does
  /// nothing for a game that isn't installed (downloads have Cancel). If
  /// deleting the files fails or is refused (a folder that contains another
  /// game's install, a symlink, ...) the error propagates and the game stays
  /// installed with its config untouched.
  Future<void> uninstallGame(
    int gameId, {
    required bool deleteFiles,
    required bool deletePrefix,
  }) async {
    if (_ref.read(launchStateProvider).isActive(gameId)) {
      throw const UninstallError('Stop the game first');
    }
    if (_ref.read(savesStateProvider).taskFor(gameId)?.status ==
        TaskStatus.running) {
      throw const UninstallError('Wait for the save sync to finish first');
    }
    if (_ref.read(gamesStateProvider).getGameStatus(gameId) !=
        GameStatus.downloaded) {
      return;
    }

    final downloads = _ref.read(downloadsStateProvider.notifier);
    await downloads.stopJob(gameId);

    final installPath = _ref.read(gamesStateProvider).getInstallPath(gameId);
    if (deleteFiles && installPath != null) {
      if (containsOtherInstall(
        _ref.read(gamesStateProvider),
        gameId,
        installPath,
      )) {
        throw const UninstallError(
          "That folder contains another game's install, so it is not deleted",
        );
      }
      await deleteDirectoryGuarded(installPath, purpose: 'game install');
    }

    if (deletePrefix) {
      // Only the Lumen-owned path, even if a stored protonPrefixPath differs.
      await deleteDirectoryGuarded(
        protonPrefixDir(gameId),
        purpose: 'Wine prefix',
      );
      for (final log in [gameLogPath(gameId), previousGameLogPath(gameId)]) {
        final file = File(log);
        if (file.existsSync()) {
          await file.delete();
        }
      }
    }

    _ref.read(gamesStateProvider.notifier).removeGame(gameId);
    downloads.removeTask(gameId);
  }
}

final uninstallerProvider = Provider<Uninstaller>(
  Uninstaller.new,
  name: 'uninstallerProvider',
);
