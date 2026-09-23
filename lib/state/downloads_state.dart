import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl_flutter/gogdl_flutter.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/common/gog_error.dart';

enum TaskKind { download, verification, repair }

enum TaskStatus { running, completed, failed }

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
    );
  }
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

/// The bridge's verification stream is single-subscription, and [GogState]
/// caches one stream per game, so this must be the sole listener — any UI
/// that needs progress reads it from [DownloadsState] instead of the raw
/// stream.
class DownloadsNotifier extends Notifier<DownloadsState> {
  late final GogState _gogState;
  late final GamesNotifier _gamesNotifier;

  @override
  DownloadsState build() {
    _gogState = ref.read(gogStateProvider);
    _gamesNotifier = ref.read(gamesStateProvider.notifier);
    ref.onDispose(() => _trailingTimer?.cancel());
    return const DownloadsState.empty();
  }

  // Not-yet-flushed tasks, keyed by gameId. [_commit] writes throttled
  // updates here instead of straight to [state]; [_emit] merges them in and
  // clears the buffer.
  final Map<int, ActivityTask> _pending = {};

  void _emit() {
    _trailingTimer?.cancel();
    _trailingTimer = null;
    state = DownloadsState({...state.tasks, ..._pending});
    _pending.clear();
  }

  // Byte-progress events can fire many times per second and each _emit()
  // triggers a full rebuild of whatever's watching the provider (e.g. the
  // Downloads page). Throttle those high-frequency progress updates to
  // ~10Hz with a trailing flush so the UI stays smooth without ever
  // dropping the final value. Terminal/status-transition emits (onDone,
  // onError) still call _emit() directly so they land
  // immediately.
  static const _emitThrottle = Duration(milliseconds: 100);
  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _trailingTimer;

  void _emitThrottled() {
    final elapsed = DateTime.now().difference(_lastEmit);
    if (elapsed >= _emitThrottle) {
      _lastEmit = DateTime.now();
      _emit();
    } else {
      _trailingTimer ??= Timer(_emitThrottle - elapsed, () {
        _trailingTimer = null;
        _lastEmit = DateTime.now();
        _emit();
      });
    }
  }

  /// Commits [next] as the replacement for [current] if [current] is still
  /// the task registered for its game — either the latest buffered value in
  /// [_pending], or (if nothing's buffered) the value in [state.tasks]. A
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
    final registered = _pending[next.gameId] ?? state.tasks[next.gameId];
    if (identical(registered, current)) {
      _pending[next.gameId] = next;
      throttle ? _emitThrottled() : _emit();
    }
    return next;
  }

  /// Removes a task from the registry, e.g. to dequeue a failed verification
  /// before starting a repair for the same game.
  void removeTask(int gameId) {
    _pending.remove(gameId);
    state = DownloadsState({...state.tasks}..remove(gameId));
  }

  /// Starts an Import verification for [gameId], or restarts one whose
  /// previous attempt failed or completed. A still-[TaskStatus.running] task
  /// for the same game blocks a second start; a failed/completed one is
  /// dequeued first — same trick [startDownload] uses — since the bridge's
  /// verification stream is single-subscription and a stale cache entry
  /// would otherwise make a re-import silently no-op or re-listen to an
  /// already-closed stream.
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
      _gogState.clearVerificationStream(gameId);
    }
    var task = ActivityTask(
      gameId: gameId,
      kind: TaskKind.verification,
      path: path,
      buildName: buildName,
      productIds: productIds,
    );
    _pending.remove(gameId);
    state = DownloadsState({...state.tasks, gameId: task});

    final stream = await _gogState.verifyGameFiles(
      gameId,
      path,
      buildName,
      productIds,
    );
    if (stream == null) {
      task = _commit(task, task.copyWith(status: TaskStatus.failed));
      return;
    }

    stream.listen(
      (event) {
        final prev = task;
        switch (event) {
          case VerifyDownloadProgress_Started(:final field0):
            task = task.copyWith(totalBytes: field0.toInt(), stage: 'verifying');
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
        }
        task = _commit(prev, task, throttle: true);
      },
      onDone: () {
        final finished = task.chunksToRedownload == 0 && task.errorFiles.isEmpty;
        final next = task.copyWith(
          status: finished ? TaskStatus.completed : TaskStatus.failed,
        );
        if (finished && task.path != null) {
          _gamesNotifier.markInstalled(gameId, task.path!);
        }
        task = _commit(task, next);
      },
      onError: (Object error) {
        logGogError(error);
        task = _commit(task, task.copyWith(status: TaskStatus.failed));
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
  /// existing task and clears the cached verification stream first — unlike
  /// [startVerification], it doesn't check whether that task is still
  /// running — same trick [startRepair] uses.
  Future<void> startVerificationForInstalled(
    int gameId, {
    required String path,
    required String buildName,
    required List<int> productIds,
  }) async {
    removeTask(gameId);
    _gogState.clearVerificationStream(gameId);
    await startVerification(
      gameId,
      path: path,
      buildName: buildName,
      productIds: productIds,
    );
  }

  /// Starts a download for [gameId], or restarts one whose previous attempt
  /// failed. A still-[TaskStatus.running] task for the same game blocks a
  /// second start; a failed/completed one is dequeued first — same trick
  /// [startRepair] uses — since the bridge's download stream is
  /// single-subscription and a stale cache entry would otherwise make the
  /// retry silently no-op or re-listen to an already-closed stream.
  Future<void> startDownload(
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
      _gogState.clearDownloadStream(gameId);
    }

    var task = ActivityTask(
      gameId: gameId,
      kind: TaskKind.download,
      path: path,
      buildName: buildName,
      productIds: productIds,
    );
    _pending.remove(gameId);
    state = DownloadsState({...state.tasks, gameId: task});
    _gamesNotifier.setGameStatus(gameId, GameStatus.downloading);

    final stream = await _gogState.downloadGameFiles(
      gameId,
      path,
      buildName,
      productIds,
    );
    if (stream == null) {
      final next = task.copyWith(status: TaskStatus.failed);
      _gamesNotifier.setGameStatus(gameId, GameStatus.notInstalled);
      task = _commit(task, next);
      return;
    }

    stream.listen(
      (event) {
        final prev = task;
        switch (event) {
          case DownloadGameProgress_Started(:final totalFiles, :final totalBytes):
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
        }
        task = _commit(prev, task, throttle: true);
      },
      onDone: () {
        final finished = task.stage == 'finished' && task.errorFiles.isEmpty;
        final next = task.copyWith(
          status: finished ? TaskStatus.completed : TaskStatus.failed,
        );
        if (finished) {
          if (task.path != null) {
            _gamesNotifier.markInstalled(gameId, task.path!);
          }
        } else {
          _gamesNotifier.setGameStatus(gameId, GameStatus.notInstalled);
        }
        task = _commit(task, next);
      },
      onError: (Object error) {
        logGogError(error);
        final next = task.copyWith(status: TaskStatus.failed);
        _gamesNotifier.setGameStatus(gameId, GameStatus.notInstalled);
        task = _commit(task, next);
      },
    );
  }

  /// Dequeues a failed verification (or previously-failed repair) task and
  /// starts repairing the same game, tracked as a [TaskKind.repair] task in
  /// the Downloads section. A still-[TaskStatus.running] task for the same
  /// game blocks a second start, same as [startDownload].
  Future<void> startRepair(int gameId) async {
    final existing = state.tasks[gameId];
    if (existing == null || existing.path == null || existing.buildName == null) {
      return;
    }
    if (existing.status == TaskStatus.running) {
      return;
    }
    final path = existing.path!;
    final buildName = existing.buildName!;
    final productIds = existing.productIds;

    removeTask(gameId);
    _gogState.clearVerificationStream(gameId);
    _gogState.clearRepairStream(gameId);

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
  /// task for the game blocks a second start; anything else is dequeued and
  /// its streams cleared first, same trick [startVerificationForInstalled]
  /// uses.
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
    _gogState.clearVerificationStream(gameId);
    _gogState.clearRepairStream(gameId);

    await _runRepair(
      gameId,
      path: path,
      buildName: buildName,
      productIds: productIds,
    );
  }

  Future<void> _runRepair(
    int gameId, {
    required String path,
    required String buildName,
    required List<int> productIds,
  }) async {
    var task = ActivityTask(
      gameId: gameId,
      kind: TaskKind.repair,
      path: path,
      buildName: buildName,
      productIds: productIds,
    );
    _pending.remove(gameId);
    state = DownloadsState({...state.tasks, gameId: task});

    final stream = await _gogState.repairGameFiles(
      gameId,
      path,
      buildName,
      productIds,
    );
    if (stream == null) {
      task = _commit(task, task.copyWith(status: TaskStatus.failed));
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
        }
        task = _commit(prev, task, throttle: true);
      },
      onDone: () {
        final finished = task.stage == 'finished' && task.errorFiles.isEmpty;
        final next = task.copyWith(
          status: finished ? TaskStatus.completed : TaskStatus.failed,
        );
        if (finished && task.path != null) {
          _gamesNotifier.markInstalled(gameId, task.path!);
        }
        task = _commit(task, next);
      },
      onError: (Object error) {
        logGogError(error);
        task = _commit(task, task.copyWith(status: TaskStatus.failed));
      },
    );
  }
}

final downloadsStateProvider =
    NotifierProvider<DownloadsNotifier, DownloadsState>(
      DownloadsNotifier.new,
      name: 'downloadsStateProvider',
    );
