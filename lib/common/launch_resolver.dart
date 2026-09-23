import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../models/launch_target.dart';
import '../state/games_state.dart';
import 'executable_finder.dart';
import 'goggame_info.dart';

/// Asks the user to choose one of several scanned executables; returns null
/// if they canceled. [notice], when set, explains why they're being asked
/// (a stale override was just cleared).
typedef PickExecutable =
    Future<String?> Function(List<String> candidates, {String? notice});

typedef PathExists = Future<bool> Function(String path);

typedef ScanExecutables = Future<List<String>> Function(String installPath);
typedef ReadPrimaryPlayTask =
    Future<LaunchTarget?> Function(String installPath, int gameId);
typedef ListPlayTasks =
    Future<List<({String name, LaunchTarget target})>> Function(
      String installPath,
      int gameId,
    );

/// The outcome of [LaunchResolver.resolve]: what to launch, if anything,
/// and a message for the user, if any. [message] is shown whether or not
/// [target] is null.
class LaunchResolution {
  final LaunchTarget? target;
  final String? message;

  const LaunchResolution({this.target, this.message});
}

/// What "auto" currently resolves to, without prompting: [target] when
/// there's a single answer, otherwise [candidateCount] tells "the user will
/// choose on first play" (several) apart from "nothing found" (0).
class AutoPreview {
  final LaunchTarget? target;
  final int candidateCount;

  const AutoPreview({this.target, this.candidateCount = 0});
}

/// Resolves which executable a game launches with, shared by Play and the
/// game's Settings tab. The order is:
/// 1. the user's override (`GameConfig.executable`), if set and still on
///    disk. A stale one (deleted by a game update, say) is cleared, so the
///    game falls back to auto, and the user is told why,
/// 2. the install's `goggame-<gameId>.info` play task ([readPrimaryPlayTask]),
/// 3. the [findExecutablesAsync] scan: one candidate is used directly,
///    several go to a picker.
///
/// `GameConfig.executable` is a user override only: steps 2 and 3 are
/// re-resolved on every launch and never persisted, so a game update that
/// changes its exe is followed automatically. Only a choice the user made
/// in a picker is saved.
///
/// A missing install folder stops resolution with a message saying so,
/// rather than scanning nothing, and leaves the override alone.
class LaunchResolver {
  LaunchResolver(
    this._ref, {
    this.scan = findExecutablesAsync,
    this.readPrimary = readPrimaryPlayTask,
    this.listTasks = listPlayTasks,
    this.fileExists = _fileExists,
    this.dirExists = _dirExists,
  });

  final Ref _ref;

  // Injectable so tests can gate or fake them; `findExecutablesAsync` runs
  // on a real isolate, which never completes under `testWidgets`' fake
  // async.
  final ScanExecutables scan;
  final ReadPrimaryPlayTask readPrimary;
  final ListPlayTasks listTasks;
  final PathExists fileExists;
  final PathExists dirExists;

  static Future<bool> _fileExists(String path) => File(path).exists();
  static Future<bool> _dirExists(String path) => Directory(path).exists();

  /// Resolves [gameId]'s launch target under [installPath], calling [pick]
  /// only when the scan finds several candidates. A picked executable is
  /// persisted as the game's override.
  Future<LaunchResolution> resolve(
    int gameId,
    String installPath, {
    required PickExecutable pick,
  }) async {
    if (!await dirExists(installPath)) {
      return LaunchResolution(
        message: "The install folder $installPath no longer exists",
      );
    }

    String? stale;
    if (await isOverrideMissing(gameId, installPath)) {
      stale = _ref.read(gamesStateProvider).getExecutable(gameId);
      _ref.read(gamesStateProvider.notifier).setExecutable(gameId, null);
    } else {
      final override = await overrideTarget(gameId, installPath);
      if (override != null) {
        return LaunchResolution(target: override);
      }
    }
    final staleNotice = stale == null
        ? null
        : '"$stale" is no longer in the install folder';

    LaunchResolution auto(LaunchTarget target) => LaunchResolution(
      target: target,
      message: staleNotice == null
          ? null
          : "$staleNotice — using ${target.executable} instead",
    );

    final playTask = await readPrimary(installPath, gameId);
    if (playTask != null) {
      return auto(playTask);
    }

    final candidates = await scan(installPath);
    if (candidates.isEmpty) {
      return LaunchResolution(
        message: staleNotice == null
            ? "No launchable .exe found in $installPath"
            : "$staleNotice, and no other .exe was found in $installPath",
      );
    }
    if (candidates.length == 1) {
      return auto(
        LaunchTarget(
          executable: candidates.first,
          source: LaunchTargetSource.scan,
        ),
      );
    }

    // The picker shows the notice itself, so there's no message after it.
    final chosen = await pick(
      candidates,
      notice: staleNotice == null ? null : "$staleNotice — choose another",
    );
    if (chosen == null) {
      return const LaunchResolution();
    }
    _ref.read(gamesStateProvider.notifier).setExecutable(gameId, chosen);
    return LaunchResolution(
      target: LaunchTarget(
        executable: chosen,
        source: LaunchTargetSource.userOverride,
      ),
    );
  }

  /// Whether [gameId] has an override that no longer exists under
  /// [installPath].
  Future<bool> isOverrideMissing(int gameId, String installPath) async {
    final executable = _ref.read(gamesStateProvider).getExecutable(gameId);
    return executable != null &&
        !await fileExists(p.join(installPath, executable));
  }

  /// [gameId]'s stored override as a target, or null if none is set. An
  /// override that matches one of the install's GOG play tasks keeps that
  /// task's working dir and arguments, since only the exe path is stored.
  Future<LaunchTarget?> overrideTarget(int gameId, String installPath) async {
    final executable = _ref.read(gamesStateProvider).getExecutable(gameId);
    if (executable == null) {
      return null;
    }
    final tasks = await listTasks(installPath, gameId);
    final match = tasks
        .where((t) => t.target.executable == executable)
        .firstOrNull;
    return LaunchTarget(
      executable: executable,
      workingDir: match?.target.workingDir,
      arguments: match?.target.arguments ?? const [],
      source: LaunchTargetSource.userOverride,
    );
  }

  /// What "auto" (no override) would launch right now, without prompting or
  /// persisting anything.
  Future<AutoPreview> previewAuto(int gameId, String installPath) async {
    final playTask = await readPrimary(installPath, gameId);
    if (playTask != null) {
      return AutoPreview(target: playTask, candidateCount: 1);
    }
    final candidates = await scan(installPath);
    if (candidates.length == 1) {
      return AutoPreview(
        target: LaunchTarget(
          executable: candidates.first,
          source: LaunchTargetSource.scan,
        ),
        candidateCount: 1,
      );
    }
    return AutoPreview(candidateCount: candidates.length);
  }

  /// Every executable the user can choose as an override: the install's
  /// named GOG play tasks first, then the scan results not already listed.
  /// [labels] maps a GOG task's path to its display name.
  Future<({List<String> candidates, Map<String, String> labels})>
  listCandidates(int gameId, String installPath) async {
    final tasks = await listTasks(installPath, gameId);
    final scanned = await scan(installPath);
    final labels = <String, String>{
      for (final task in tasks) task.target.executable: "GOG: ${task.name}",
    };
    return (
      candidates: [
        ...labels.keys,
        ...scanned.where((path) => !labels.containsKey(path)),
      ],
      labels: labels,
    );
  }
}

final launchResolverProvider = Provider<LaunchResolver>(
  LaunchResolver.new,
  name: 'launchResolverProvider',
);
