import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl_flutter/gogdl_flutter.dart';
import 'package:lumen/common/gog_error.dart';
import 'package:lumen/common/safe_delete.dart';
import 'package:lumen/state/emit_throttle.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_backend.dart' show JobCancel;
import 'package:lumen/state/gog_state.dart';
import 'package:path/path.dart' as p;

enum TaskKind { download, verification, repair }

/// [cancelled] is a user-requested stop that discards the work (a cancelled
/// verification or repair, or a download cancelled without keeping its
/// files): not a failure, and not shown as one. [paused] is a download stopped
/// with its partial files kept, resumable through [DownloadsNotifier.resumeDownload].
enum TaskStatus { running, completed, failed, cancelled, paused }

/// Why a file failed verification, from the three per-path failure events on
/// the bridge's `VerifyDownloadProgress` stream.
enum VerifyFailure { missing, corrupt, unreadable }

/// Sentinel default for nullable [ActivityTask.copyWith] parameters, so
/// "argument omitted" (keep the existing value) can be distinguished from
/// "argument explicitly passed as `null`" (clear the field) — same pattern
/// as `GameConfig.copyWith`'s `_unset` in games_state.dart.
const _unset = Object();

/// Immutable snapshot of one in-flight/finished download, verification or
/// repair job. Updates go through [copyWith]; [DownloadsNotifier] is the
/// only thing that constructs new ones.
class ActivityTask {
  final int gameId;
  final TaskKind kind;
  final TaskStatus status;
  final List<String> errorFiles;

  // Verification and repair: which of the damaged files failed for which
  // reason, and (verification only) the chunk count from the terminal
  // `finished` event (null until then). [errorFiles] is derived from this
  // map's keys for verification; for repair, [errorFiles] stays reserved
  // for genuine allocation errors and damaged files live only here.
  final Map<String, VerifyFailure> verifyFailures;
  final int? chunksToRedownload;

  // Download/repair/verification progress (bytes-based) and current stage.
  // Verification stages: "verifying". Repair stages: "checkingFiles",
  // "allocating", "verifyingChunks", "downloading", "finished". Download
  // stages: "checkingFiles", "allocating", "downloading", "finished".
  final int totalBytes;
  final int downloadedBytes;
  final String? stage;

  // Download only: the file-counted pre-transfer stages (size verification,
  // then allocation). Each stage resets these against its own denominator;
  // [totalBytes]/[downloadedBytes] stay the compressed-transfer pair.
  final int totalFiles;
  final int processedFiles;

  // Launch params, persisted so a repair can be started later from the card.
  final String? path;
  final String? buildName;
  final List<int> productIds;

  // Set on a failed task from the bridge error (or a local reason, e.g. a
  // stream that couldn't even be started) so the Downloads page can show
  // more than a generic "<kind> failed" — see downloads_page.dart's status
  // helpers.
  final String? error;

  // Download only: this task is a resume of a paused download, running as a
  // repair job underneath. It still reads as a download, but its first stages
  // are "Resuming — verifying downloaded files…".
  final bool resumed;

  ActivityTask({
    required this.gameId,
    required this.kind,
    this.status = TaskStatus.running,
    List<String> errorFiles = const [],
    Map<String, VerifyFailure> verifyFailures = const {},
    this.chunksToRedownload,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.stage,
    this.totalFiles = 0,
    this.processedFiles = 0,
    this.path,
    this.buildName,
    List<int> productIds = const [],
    this.error,
    this.resumed = false,
  }) : errorFiles = List.unmodifiable(errorFiles),
       verifyFailures = Map.unmodifiable(verifyFailures),
       productIds = List.unmodifiable(productIds);

  /// Assigns every field as given, with no defaults and no re-wrapping of
  /// already-unmodifiable collections — [copyWith] is the only caller, and
  /// it decides per-field whether a collection actually changed.
  ActivityTask._({
    required this.gameId,
    required this.kind,
    required this.status,
    required this.errorFiles,
    required this.verifyFailures,
    required this.chunksToRedownload,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.stage,
    required this.totalFiles,
    required this.processedFiles,
    required this.path,
    required this.buildName,
    required this.productIds,
    required this.error,
    required this.resumed,
  });

  int verifyFailureCount(VerifyFailure kind) =>
      verifyFailures.values.where((f) => f == kind).length;

  /// Fraction complete for the task's current stage, or null when the
  /// denominator isn't known yet (drives the indeterminate bar). Download
  /// tasks are file-counted before the transfer starts and byte-counted
  /// during it; verification and repair are always byte-counted.
  double? get progress {
    final fileCounted =
        kind != TaskKind.verification &&
        (stage == 'checkingFiles' || stage == 'allocating');
    if (fileCounted) {
      return totalFiles > 0 ? processedFiles / totalFiles : null;
    }
    return totalBytes > 0 ? downloadedBytes / totalBytes : null;
  }

  /// Returns a copy with the given fields replaced. [chunksToRedownload],
  /// [stage], [path] and [buildName] default to the [_unset] sentinel
  /// rather than `null`, so omitting them keeps the existing value while
  /// passing `null` explicitly clears them. Collections are only re-wrapped
  /// with `List`/`Map.unmodifiable` when actually replaced, so an unchanged
  /// collection keeps its already-unmodifiable instance instead of being
  /// copied again on every event.
  ActivityTask copyWith({
    TaskStatus? status,
    List<String>? errorFiles,
    Map<String, VerifyFailure>? verifyFailures,
    Object? chunksToRedownload = _unset,
    int? totalBytes,
    int? downloadedBytes,
    Object? stage = _unset,
    int? totalFiles,
    int? processedFiles,
    Object? path = _unset,
    Object? buildName = _unset,
    List<int>? productIds,
    Object? error = _unset,
    bool? resumed,
  }) {
    return ActivityTask._(
      gameId: gameId,
      kind: kind,
      status: status ?? this.status,
      errorFiles: errorFiles == null
          ? this.errorFiles
          : List.unmodifiable(errorFiles),
      verifyFailures: verifyFailures == null
          ? this.verifyFailures
          : Map.unmodifiable(verifyFailures),
      chunksToRedownload: identical(chunksToRedownload, _unset)
          ? this.chunksToRedownload
          : chunksToRedownload as int?,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      stage: identical(stage, _unset) ? this.stage : stage as String?,
      totalFiles: totalFiles ?? this.totalFiles,
      processedFiles: processedFiles ?? this.processedFiles,
      path: identical(path, _unset) ? this.path : path as String?,
      buildName: identical(buildName, _unset)
          ? this.buildName
          : buildName as String?,
      productIds: productIds == null
          ? this.productIds
          : List.unmodifiable(productIds),
      error: identical(error, _unset) ? this.error : error as String?,
      resumed: resumed ?? this.resumed,
    );
  }
}

/// Whether [path] is, or contains, another game's install (or pending
/// install) folder, so deleting it would take that game with it.
bool containsOtherInstall(GamesState games, int gameId, String path) {
  for (final entry in games.games.entries) {
    if (entry.key == gameId) continue;
    for (final other in [
      entry.value.installPath,
      entry.value.pendingInstallPath,
    ]) {
      if (other != null && (p.equals(path, other) || p.isWithin(path, other))) {
        return true;
      }
    }
  }
  return false;
}

const _couldNotStart =
    "Lumen couldn't start the job — try again, or restart Lumen if it keeps "
    'happening';

/// Why a running download job is being stopped: [pause] keeps the partial
/// files for a later resume, [discard] is a cancel that throws them away.
enum _StopIntent { pause, discard }

/// The handle of one running job, kept out of the immutable [ActivityTask]
/// snapshots (same idea as `LaunchNotifier`'s `_LiveLaunch`).
class _LiveJob {
  final JobCancel cancel = JobCancel();

  /// Completes once the job's stream has ended, for whatever reason.
  final Completer<void> done = Completer<void>();

  /// Set before [cancel] fires on a download, so the terminal `Cancelled`
  /// event knows which of pause/cancel it is. Unset means pause: keeping the
  /// files is the safe reading.
  _StopIntent? intent;
}

/// Immutable snapshot of in-flight/finished download & verification tasks,
/// keyed by gameId. Read-only — mutations go through [DownloadsNotifier] via
/// `downloadsStateProvider.notifier`.
class DownloadsState {
  final Map<int, ActivityTask> tasks;

  const DownloadsState(this.tasks);

  const DownloadsState.empty() : tasks = const {};

  List<ActivityTask> get verificationTasks =>
      tasks.values.where((task) => task.kind == TaskKind.verification).toList();

  List<ActivityTask> get downloadTasks =>
      tasks.values.where((task) => task.kind == TaskKind.download).toList();

  List<ActivityTask> get repairTasks =>
      tasks.values.where((task) => task.kind == TaskKind.repair).toList();
}

/// The bridge's verification, download and repair streams are
/// single-subscription, so this must be the sole listener for whatever
/// stream it requests from [GogState] — any UI that needs progress reads it
/// from [DownloadsState] instead of the raw stream.
class DownloadsNotifier extends Notifier<DownloadsState> {
  late final GogState _gogState;
  late final GamesNotifier _gamesNotifier;

  @override
  DownloadsState build() {
    _gogState = ref.read(gogStateProvider);
    _gamesNotifier = ref.read(gamesStateProvider.notifier);
    _buffer = ThrottledTaskBuffer<int, ActivityTask>(
      (pending) => state = DownloadsState({...state.tasks, ...pending}),
    );
    ref.onDispose(_buffer.dispose);
    return const DownloadsState.empty();
  }

  // Byte-progress events can fire many times per second and each flush
  // triggers a full rebuild of whatever's watching the provider (e.g. the
  // Downloads page). [_buffer] throttles those high-frequency progress
  // updates to ~10Hz with a trailing flush so the UI stays smooth without
  // ever dropping the final value. Terminal/status-transition commits pass
  // `throttle: false` so they land immediately instead of waiting behind a
  // trailing flush. See lib/state/emit_throttle.dart.
  late final ThrottledTaskBuffer<int, ActivityTask> _buffer;

  final Map<int, _LiveJob> _jobs = {};

  /// Drops [job] from the registry, but only if it's still the job
  /// registered for [gameId]: a stale stream finishing late must not
  /// unregister the job that replaced it. Always completes [_LiveJob.done].
  void _release(int gameId, _LiveJob job) {
    if (identical(_jobs[gameId], job)) {
      _jobs.remove(gameId);
    }
    if (!job.done.isCompleted) {
      job.done.complete();
    }
  }

  /// Asks the running verification or repair for [gameId] to stop. A no-op
  /// for anything else (no task, a finished task, a download — use [pause] or
  /// [cancelDownload]). Commits nothing itself: the job's terminal
  /// `Cancelled` event does, through [_commit], so the stale-stream guard
  /// still applies.
  void cancel(int gameId) {
    final task = state.tasks[gameId];
    if (task == null ||
        task.status != TaskStatus.running ||
        task.kind == TaskKind.download) {
      return;
    }
    _jobs[gameId]?.cancel.cancel();
  }

  /// Stops whatever job is running for [gameId] (verification, repair or
  /// download) and waits for its stream to end. A download is discarded, not
  /// paused. A no-op when nothing is running. Used by uninstall.
  Future<void> stopJob(int gameId) async {
    final task = state.tasks[gameId];
    final job = _jobs[gameId];
    if (task == null || job == null || task.status != TaskStatus.running) {
      return;
    }
    job.intent = _StopIntent.discard;
    job.cancel.cancel();
    await job.done.future;
  }

  /// Pauses the running download for [gameId]: the job stops and its partial
  /// files stay put. The terminal `Cancelled` event commits
  /// [TaskStatus.paused] and [GameStatus.paused]. A no-op for anything that
  /// isn't a running download.
  void pause(int gameId) {
    final task = state.tasks[gameId];
    final job = _jobs[gameId];
    if (task == null ||
        job == null ||
        task.status != TaskStatus.running ||
        task.kind != TaskKind.download) {
      return;
    }
    job.intent = _StopIntent.pause;
    job.cancel.cancel();
  }

  /// The task a download's terminal `Cancelled` event turns [task] into:
  /// paused (files kept, the game becomes [GameStatus.paused]) unless the job
  /// was being discarded by [cancelDownload], which finishes the job itself.
  ActivityTask _stopped(ActivityTask task, _LiveJob job) {
    if (job.intent == _StopIntent.discard) {
      return task.copyWith(status: TaskStatus.cancelled);
    }
    _gamesNotifier.setGameStatus(task.gameId, GameStatus.paused);
    return task.copyWith(status: TaskStatus.paused);
  }

  /// Whether [path] is missing or has nothing in it.
  Future<bool> _isEmptyOrMissing(String path) async {
    try {
      final dir = Directory(path);
      return !await dir.exists() || await dir.list().isEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Cancels the download for [gameId] (running or paused), stopping the job
  /// first if it's running, then resets the game to not installed and drops
  /// its task. With [deleteFiles] the partial files go too: the whole
  /// install folder, but only if it was empty or missing when the download
  /// started (`GameConfig.ownsPendingInstallDir`) and holds no other game's
  /// install. A refused or failed delete rethrows and leaves the game
  /// paused, since its files are still there to resume from.
  Future<void> cancelDownload(int gameId, {required bool deleteFiles}) async {
    final task = state.tasks[gameId];
    final job = _jobs[gameId];
    if (job != null &&
        task != null &&
        task.kind == TaskKind.download &&
        task.status == TaskStatus.running) {
      job.intent = _StopIntent.discard;
      job.cancel.cancel();
      await job.done.future;
      if (state.tasks[gameId]?.status == TaskStatus.completed) {
        return; // it finished before the cancel landed
      }
    }

    final games = ref.read(gamesStateProvider);
    final path = games.getPendingInstallPath(gameId) ?? task?.path;
    if (deleteFiles && path != null) {
      try {
        if (games.games[gameId]?.ownsPendingInstallDir != true) {
          throw const UnsafeDeleteError(
            "That folder wasn't empty when the download started, so it "
            'is not deleted — remove the downloaded files by hand',
          );
        }
        if (containsOtherInstall(games, gameId, path)) {
          throw const UnsafeDeleteError(
            "That folder contains another game's install, so it is "
            'not deleted',
          );
        }
        await deleteDirectoryGuarded(path, purpose: 'partial download');
      } catch (_) {
        _gamesNotifier.setGameStatus(gameId, GameStatus.paused);
        final current = state.tasks[gameId];
        if (current != null) {
          _buffer.remove(gameId);
          state = DownloadsState({
            ...state.tasks,
            gameId: current.copyWith(status: TaskStatus.paused),
          });
        }
        rethrow;
      }
    }

    _gamesNotifier.clearPendingInstall(gameId);
    removeTask(gameId);
  }

  /// Commits [next] as the replacement for [current] if [current] is still
  /// the task registered for its game — either the latest buffered value in
  /// [_buffer], or (if nothing's buffered) the value in [state.tasks]. A
  /// stream whose task was dequeued (e.g. a restart while still running)
  /// keeps delivering events to an orphaned closure-local task; this stops
  /// those stale events from clobbering whatever replaced it. Returns
  /// [next] regardless, so the caller's local variable keeps evolving for
  /// its own onDone/onError decisions even once its updates stop landing.
  ActivityTask _commit(
    ActivityTask current,
    ActivityTask next, {
    bool throttle = false,
  }) {
    final registered = _buffer[next.gameId] ?? state.tasks[next.gameId];
    if (identical(registered, current)) {
      _buffer.put(next.gameId, next, throttle: throttle);
    }
    return next;
  }

  /// Removes a task from the registry, e.g. to dequeue a failed verification
  /// before starting a repair for the same game.
  void removeTask(int gameId) {
    _buffer.remove(gameId);
    state = DownloadsState({...state.tasks}..remove(gameId));
  }

  /// Starts an Import verification for [gameId], or restarts one whose
  /// previous attempt failed or completed. A still-[TaskStatus.running] task
  /// for the same game blocks a second start; a failed/completed one is
  /// dequeued first — same trick [startDownload] uses — so a re-import
  /// registers a fresh task instead of silently no-oping against the old
  /// one.
  Future<void> startVerification(
    int gameId, {
    required String path,
    required String buildName,
    required List<int> productIds,
  }) async {
    final existing = state.tasks[gameId];
    if (existing != null) {
      if (existing.status == TaskStatus.running) {
        return;
      }
      removeTask(gameId);
    }
    var task = ActivityTask(
      gameId: gameId,
      kind: TaskKind.verification,
      path: path,
      buildName: buildName,
      productIds: productIds,
    );
    _buffer.remove(gameId);
    state = DownloadsState({...state.tasks, gameId: task});

    final job = _LiveJob();
    _jobs[gameId] = job;
    final stream = _gogState.verifyGameFiles(
      gameId,
      path,
      buildName,
      productIds,
      cancel: job.cancel,
    );
    if (stream == null) {
      _release(gameId, job);
      task = _commit(
        task,
        task.copyWith(status: TaskStatus.failed, error: _couldNotStart),
      );
      return;
    }

    stream.listen(
      (event) {
        final prev = task;
        switch (event) {
          case VerifyDownloadProgress_Started(:final field0):
            task = task.copyWith(
              totalBytes: field0.toInt(),
              stage: 'verifying',
            );
          case VerifyDownloadProgress_Progress(:final field0):
            task = task.copyWith(downloadedBytes: field0.toInt());
          case VerifyDownloadProgress_CouldNotResolvePath(:final field0):
            task = _withVerifyFailure(task, field0, VerifyFailure.unreadable);
          case VerifyDownloadProgress_FileNotFound(:final field0):
            task = _withVerifyFailure(task, field0, VerifyFailure.missing);
          case VerifyDownloadProgress_ChecksumMismatch(:final field0):
            task = _withVerifyFailure(task, field0, VerifyFailure.corrupt);
          case VerifyDownloadProgress_Finished(:final field0):
            task = task.copyWith(chunksToRedownload: field0.toInt());
            task = _commit(prev, task);
            return;
          case VerifyDownloadProgress_Cancelled():
            task = task.copyWith(status: TaskStatus.cancelled);
            task = _commit(prev, task);
            return;
        }
        task = _commit(prev, task, throttle: true);
      },
      onDone: () {
        _release(gameId, job);
        if (task.status == TaskStatus.failed ||
            task.status == TaskStatus.cancelled) {
          return;
        }
        final finished =
            task.chunksToRedownload == 0 && task.errorFiles.isEmpty;
        final next = task.copyWith(
          status: finished ? TaskStatus.completed : TaskStatus.failed,
        );
        if (finished && task.path != null) {
          _gamesNotifier.markInstalled(gameId, task.path!);
        }
        task = _commit(task, next);
      },
      onError: (Object error) {
        _release(gameId, job);
        logGogError(error);
        task = _commit(
          task,
          task.copyWith(status: TaskStatus.failed, error: jobErrorText(error)),
        );
      },
    );
  }

  /// Returns [task] with one per-path damaged-file event recorded — from
  /// verification (a real failure) or repair (a file repair is about to
  /// fix). For verification, also re-derives [ActivityTask.errorFiles] from
  /// the map's keys, which is the source of truth there; repair leaves
  /// [ActivityTask.errorFiles] alone — it stays reserved for allocation
  /// errors.
  ActivityTask _withVerifyFailure(
    ActivityTask task,
    String path,
    VerifyFailure kind,
  ) {
    final verifyFailures = {...task.verifyFailures, path: kind};
    return task.copyWith(
      verifyFailures: verifyFailures,
      errorFiles: task.kind == TaskKind.verification
          ? verifyFailures.keys.toList()
          : null,
    );
  }

  /// Verifies an already-installed game. Unconditionally dequeues any
  /// existing task first — unlike [startVerification], it doesn't check
  /// whether that task is still running — same trick [startRepair] uses.
  Future<void> startVerificationForInstalled(
    int gameId, {
    required String path,
    required String buildName,
    required List<int> productIds,
  }) async {
    removeTask(gameId);
    await startVerification(
      gameId,
      path: path,
      buildName: buildName,
      productIds: productIds,
    );
  }

  /// Starts a download for [gameId], or restarts one whose previous attempt
  /// failed. A still-[TaskStatus.running] task for the same game blocks a
  /// second start, and so does a paused one (use [resumeDownload]); a
  /// failed/completed one is dequeued first — same trick [startRepair] uses —
  /// so a retry registers a fresh task instead of silently no-oping against
  /// the old one.
  Future<void> startDownload(
    int gameId, {
    required String path,
    required String buildName,
    required List<int> productIds,
  }) async {
    final existing = state.tasks[gameId];
    if (ref.read(gamesStateProvider).getGameStatus(gameId) ==
        GameStatus.paused) {
      return;
    }
    if (existing != null) {
      if (existing.status == TaskStatus.running ||
          existing.status == TaskStatus.paused) {
        return;
      }
      removeTask(gameId);
    }

    var task = ActivityTask(
      gameId: gameId,
      kind: TaskKind.download,
      path: path,
      buildName: buildName,
      productIds: productIds,
    );
    _buffer.remove(gameId);
    state = DownloadsState({...state.tasks, gameId: task});

    final job = _LiveJob();
    _jobs[gameId] = job;
    // The task is registered first, so a second start during this await is
    // blocked; the folder is inspected before the job can write to it.
    final ownsDir = await _isEmptyOrMissing(path);
    _gamesNotifier.beginInstall(gameId, path, ownsDir: ownsDir);
    final stream = _gogState.downloadGameFiles(
      gameId,
      path,
      buildName,
      productIds,
      cancel: job.cancel,
    );
    if (stream == null) {
      _release(gameId, job);
      final next = task.copyWith(
        status: TaskStatus.failed,
        error: _couldNotStart,
      );
      _gamesNotifier.clearPendingInstall(gameId);
      task = _commit(task, next);
      return;
    }

    stream.listen(
      (event) {
        final prev = task;
        switch (event) {
          case DownloadGameProgress_Started(
            :final totalFiles,
            :final totalBytes,
          ):
            task = task.copyWith(
              totalFiles: totalFiles.toInt(),
              totalBytes: totalBytes.toInt(),
              processedFiles: 0,
              stage: 'checkingFiles',
            );
          case DownloadGameProgress_FileSizeVerification(:final checkedFiles):
            task = task.copyWith(processedFiles: checkedFiles.toInt());
          case DownloadGameProgress_FileAllocationStarted(:final totalFiles):
            task = task.copyWith(
              totalFiles: totalFiles.toInt(),
              processedFiles: 0,
              stage: 'allocating',
            );
          case DownloadGameProgress_FileAllocation(:final allocatedFiles):
            task = task.copyWith(processedFiles: allocatedFiles.toInt());
          case DownloadGameProgress_AllocationError(:final field0):
            task = task.copyWith(errorFiles: [...task.errorFiles, field0]);
          case DownloadGameProgress_DownloadProgress(:final downloadedBytes):
            task = task.copyWith(
              downloadedBytes: downloadedBytes.toInt(),
              stage: 'downloading',
            );
          case DownloadGameProgress_Finished():
            task = task.copyWith(stage: 'finished');
            task = _commit(prev, task);
            return;
          case DownloadGameProgress_Cancelled():
            task = _stopped(task, job);
            task = _commit(prev, task);
            return;
        }
        task = _commit(prev, task, throttle: true);
      },
      onDone: () {
        _release(gameId, job);
        if (task.status == TaskStatus.failed ||
            task.status == TaskStatus.cancelled ||
            task.status == TaskStatus.paused) {
          return;
        }
        final finished = task.stage == 'finished' && task.errorFiles.isEmpty;
        final next = task.copyWith(
          status: finished ? TaskStatus.completed : TaskStatus.failed,
        );
        if (finished) {
          if (task.path != null) {
            _gamesNotifier.markInstalled(gameId, task.path!);
          }
        }
        task = _commit(task, next);
        if (!finished) {
          unawaited(_settleFailedDownload(gameId, path));
        }
      },
      onError: (Object error) {
        _release(gameId, job);
        logGogError(error);
        final next = task.copyWith(
          status: TaskStatus.failed,
          error: jobErrorText(error),
        );
        task = _commit(task, next);
        unawaited(_settleFailedDownload(gameId, path));
      },
    );
  }

  /// What a failed download leaves the game as. A folder holding files is a
  /// resumable partial install, the same state as a failed resume
  /// ([GameStatus.paused], path kept); an empty or missing one has nothing to
  /// resume, so the game goes back to not installed.
  Future<void> _settleFailedDownload(int gameId, String path) async {
    final hasFiles = !await _isEmptyOrMissing(path);
    if (!ref.mounted) return;
    final games = ref.read(gamesStateProvider);
    if (games.getGameStatus(gameId) != GameStatus.downloading ||
        _jobs.containsKey(gameId)) {
      return; // something else took over while the folder was inspected
    }
    if (hasFiles) {
      _gamesNotifier.setGameStatus(gameId, GameStatus.paused);
    } else {
      _gamesNotifier.clearPendingInstall(gameId);
    }
  }

  /// Retries a failed download: a paused game (partial files on disk) resumes
  /// through [resumeDownload], which always runs `repairDownload`; otherwise
  /// the failed task's params start a fresh download. A no-op for anything
  /// else.
  Future<void> retryDownload(int gameId) async {
    if (ref.read(gamesStateProvider).getGameStatus(gameId) ==
        GameStatus.paused) {
      return resumeDownload(gameId);
    }
    final task = state.tasks[gameId];
    if (task == null ||
        task.kind != TaskKind.download ||
        task.status != TaskStatus.failed ||
        task.path == null ||
        task.buildName == null) {
      return;
    }
    await startDownload(
      gameId,
      path: task.path!,
      buildName: task.buildName!,
      productIds: task.productIds,
    );
  }

  /// Whether [task] is finished and can be dismissed: completed, failed or
  /// cancelled. A failed download of a paused game can't: its files are still
  /// there, so it's resumed or cancelled instead.
  bool isDismissible(ActivityTask task) {
    switch (task.status) {
      case TaskStatus.running || TaskStatus.paused:
        return false;
      case TaskStatus.completed || TaskStatus.cancelled:
        return true;
      case TaskStatus.failed:
        return !(task.kind == TaskKind.download &&
            ref.read(gamesStateProvider).getGameStatus(task.gameId) ==
                GameStatus.paused);
    }
  }

  /// Removes every dismissible finished task ([isDismissible]) at once.
  void clearFinished() {
    final remaining = <int, ActivityTask>{};
    for (final entry in state.tasks.entries) {
      if (isDismissible(entry.value)) {
        _buffer.remove(entry.key);
      } else {
        remaining[entry.key] = entry.value;
      }
    }
    state = DownloadsState(remaining);
  }

  /// Dequeues a failed verification (or previously-failed repair) task and
  /// starts repairing the same game, tracked as a [TaskKind.repair] task in
  /// the Downloads section. A still-[TaskStatus.running] task for the same
  /// game blocks a second start, same as [startDownload].
  Future<void> startRepair(int gameId) async {
    final existing = state.tasks[gameId];
    if (existing == null ||
        existing.path == null ||
        existing.buildName == null) {
      return;
    }
    if (existing.status == TaskStatus.running) {
      return;
    }
    final path = existing.path!;
    final buildName = existing.buildName!;
    final productIds = existing.productIds;

    removeTask(gameId);

    await _runRepair(
      gameId,
      path: path,
      buildName: buildName,
      productIds: productIds,
    );
  }

  /// Repairs an already-installed game against an explicit build (e.g. after
  /// switching builds on the Builds tab), rather than reusing a previous
  /// task's path/build/products the way [startRepair] does. A still-running
  /// task for the game blocks a second start; anything else is dequeued
  /// first, same trick [startVerificationForInstalled] uses.
  Future<void> startRepairForInstalled(
    int gameId, {
    required String path,
    required String buildName,
    required List<int> productIds,
  }) async {
    final existing = state.tasks[gameId];
    if (existing != null && existing.status == TaskStatus.running) {
      return;
    }
    removeTask(gameId);

    await _runRepair(
      gameId,
      path: path,
      buildName: buildName,
      productIds: productIds,
    );
  }

  /// Resumes the paused download for [gameId]. Always a repair job
  /// underneath, never `downloadGame`: a killed or paused download leaves
  /// its files preallocated to full size, which `download_game`'s size check
  /// would call done. The task still reads as a download ([ActivityTask.resumed]).
  /// Its params come from the game's existing download task, else from the
  /// persisted config (a pause that survived an app restart). A resume that
  /// fails leaves the game paused again, since its files are still there. If
  /// the install folder is gone (deleted, or a drive not mounted) it fails
  /// without starting a job and clears nothing, so the game can be resumed
  /// once the folder comes back.
  Future<void> resumeDownload(int gameId) async {
    final games = ref.read(gamesStateProvider);
    if (games.getGameStatus(gameId) != GameStatus.paused) {
      return;
    }
    var existing = state.tasks[gameId];
    if (existing != null && existing.status == TaskStatus.running) {
      return;
    }
    if (existing != null && existing.kind != TaskKind.download) {
      existing = null;
    }
    final path = existing?.path ?? games.getPendingInstallPath(gameId);
    final buildName = existing?.buildName ?? games.getSelectedBuild(gameId);
    final productIds =
        existing?.productIds ?? games.getProductIds(gameId).toList();
    if (path == null || buildName == null || buildName.isEmpty) {
      return;
    }

    if (!await Directory(path).exists()) {
      _buffer.remove(gameId);
      state = DownloadsState({
        ...state.tasks,
        gameId: ActivityTask(
          gameId: gameId,
          kind: TaskKind.download,
          status: TaskStatus.failed,
          path: path,
          buildName: buildName,
          productIds: productIds,
          resumed: true,
          error: 'The install folder $path no longer exists',
        ),
      });
      return;
    }
    // Re-check after the await, so two quick Resume taps can't start two jobs.
    final current = state.tasks[gameId];
    if (ref.read(gamesStateProvider).getGameStatus(gameId) !=
            GameStatus.paused ||
        (current != null && current.status == TaskStatus.running)) {
      return;
    }

    removeTask(gameId);
    _gamesNotifier.setGameStatus(gameId, GameStatus.downloading);
    await _runRepair(
      gameId,
      path: path,
      buildName: buildName,
      productIds: productIds,
      resumed: true,
    );
  }

  /// Runs a repair stream for [gameId]. With [resumed] it's a paused
  /// download being resumed: tracked as a [TaskKind.download] task, ending in
  /// `markInstalled` on success and back to [GameStatus.paused] on failure.
  Future<void> _runRepair(
    int gameId, {
    required String path,
    required String buildName,
    required List<int> productIds,
    bool resumed = false,
  }) async {
    var task = ActivityTask(
      gameId: gameId,
      kind: resumed ? TaskKind.download : TaskKind.repair,
      path: path,
      buildName: buildName,
      productIds: productIds,
      resumed: resumed,
    );
    _buffer.remove(gameId);
    state = DownloadsState({...state.tasks, gameId: task});

    final job = _LiveJob();
    _jobs[gameId] = job;
    final stream = _gogState.repairGameFiles(
      gameId,
      path,
      buildName,
      productIds,
      cancel: job.cancel,
    );
    if (stream == null) {
      _release(gameId, job);
      if (resumed) {
        _gamesNotifier.setGameStatus(gameId, GameStatus.paused);
      }
      task = _commit(
        task,
        task.copyWith(status: TaskStatus.failed, error: _couldNotStart),
      );
      return;
    }

    stream.listen(
      (event) {
        final prev = task;
        switch (event) {
          case RepairGameProgress_Started(:final totalFiles, :final totalBytes):
            task = task.copyWith(
              totalFiles: totalFiles.toInt(),
              totalBytes: totalBytes.toInt(),
              processedFiles: 0,
              stage: 'checkingFiles',
            );
          case RepairGameProgress_FileSizeVerification(:final checkedFiles):
            task = task.copyWith(processedFiles: checkedFiles.toInt());
          case RepairGameProgress_FileAllocationStarted(:final totalFiles):
            task = task.copyWith(
              totalFiles: totalFiles.toInt(),
              processedFiles: 0,
              stage: 'allocating',
            );
          case RepairGameProgress_FileAllocation(:final allocatedFiles):
            task = task.copyWith(processedFiles: allocatedFiles.toInt());
          case RepairGameProgress_AllocationError(:final field0):
            task = task.copyWith(errorFiles: [...task.errorFiles, field0]);
          case RepairGameProgress_Verification(:final checkedBytes):
            task = task.copyWith(
              downloadedBytes: checkedBytes.toInt(),
              stage: 'verifyingChunks',
            );
          case RepairGameProgress_CouldNotResolvePath(:final field0):
            task = _withVerifyFailure(task, field0, VerifyFailure.unreadable);
          case RepairGameProgress_FileNotFound(:final field0):
            task = _withVerifyFailure(task, field0, VerifyFailure.missing);
          case RepairGameProgress_ChecksumMismatch(:final field0):
            task = _withVerifyFailure(task, field0, VerifyFailure.corrupt);
          case RepairGameProgress_DownloadStarted(:final totalBytes):
            task = task.copyWith(
              totalBytes: totalBytes.toInt(),
              downloadedBytes: 0,
              stage: 'downloading',
            );
          case RepairGameProgress_DownloadProgress(:final downloadedBytes):
            task = task.copyWith(downloadedBytes: downloadedBytes.toInt());
          case RepairGameProgress_Finished():
            task = task.copyWith(stage: 'finished');
            task = _commit(prev, task);
            return;
          case RepairGameProgress_Cancelled():
            task = resumed
                ? _stopped(task, job)
                : task.copyWith(status: TaskStatus.cancelled);
            task = _commit(prev, task);
            return;
        }
        task = _commit(prev, task, throttle: true);
      },
      onDone: () {
        _release(gameId, job);
        if (task.status == TaskStatus.failed ||
            task.status == TaskStatus.cancelled ||
            task.status == TaskStatus.paused) {
          return;
        }
        final finished = task.stage == 'finished' && task.errorFiles.isEmpty;
        final next = task.copyWith(
          status: finished ? TaskStatus.completed : TaskStatus.failed,
        );
        if (finished && task.path != null) {
          _gamesNotifier.markInstalled(gameId, task.path!);
        } else if (resumed) {
          _gamesNotifier.setGameStatus(gameId, GameStatus.paused);
        }
        task = _commit(task, next);
      },
      onError: (Object error) {
        _release(gameId, job);
        logGogError(error);
        if (resumed) {
          _gamesNotifier.setGameStatus(gameId, GameStatus.paused);
        }
        task = _commit(
          task,
          task.copyWith(status: TaskStatus.failed, error: jobErrorText(error)),
        );
      },
    );
  }
}

final downloadsStateProvider =
    NotifierProvider<DownloadsNotifier, DownloadsState>(
      DownloadsNotifier.new,
      name: 'downloadsStateProvider',
    );
