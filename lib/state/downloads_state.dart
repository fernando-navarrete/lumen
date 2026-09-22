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

class ActivityTask {
  final int gameId;
  final TaskKind kind;
  TaskStatus status;
  List<String> errorFiles;

  // Verification and repair: which of the damaged files failed for which
  // reason, and (verification only) the chunk count from the terminal
  // `finished` event (null until then). [errorFiles] is derived from this
  // map's keys for verification; for repair, [errorFiles] stays reserved
  // for genuine allocation errors and damaged files live only here.
  Map<String, VerifyFailure> verifyFailures;
  int? chunksToRedownload;

  // Download/repair/verification progress (bytes-based) and current stage.
  // Verification stages: "verifying". Repair stages: "checkingFiles",
  // "allocating", "verifyingChunks", "downloading", "finished". Download
  // stages: "checkingFiles", "allocating", "downloading", "finished".
  int totalBytes;
  int downloadedBytes;
  String? stage;

  // Download only: the file-counted pre-transfer stages (size verification,
  // then allocation). Each stage resets these against its own denominator;
  // [totalBytes]/[downloadedBytes] stay the compressed-transfer pair.
  int totalFiles;
  int processedFiles;

  // Launch params, persisted so a repair can be started later from the card.
  String? path;
  String? buildName;
  List<int> productIds;

  ActivityTask({
    required this.gameId,
    required this.kind,
    this.status = TaskStatus.running,
    this.errorFiles = const [],
    this.verifyFailures = const {},
    this.chunksToRedownload,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.stage,
    this.totalFiles = 0,
    this.processedFiles = 0,
    this.path,
    this.buildName,
    this.productIds = const [],
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

  void _emit() {
    _trailingTimer?.cancel();
    _trailingTimer = null;
    state = DownloadsState({...state.tasks});
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

  /// Removes a task from the registry, e.g. to dequeue a failed verification
  /// before starting a repair for the same game.
  void removeTask(int gameId) {
    state = DownloadsState({...state.tasks}..remove(gameId));
  }

  Future<void> startVerification(
    int gameId, {
    required String path,
    required String buildName,
    required List<int> productIds,
  }) async {
    if (state.tasks.containsKey(gameId)) {
      return;
    }
    final task = ActivityTask(
      gameId: gameId,
      kind: TaskKind.verification,
      path: path,
      buildName: buildName,
      productIds: productIds,
    );
    state = DownloadsState({...state.tasks, gameId: task});

    final stream = await _gogState.verifyGameFiles(
      gameId,
      path,
      buildName,
      productIds,
    );
    if (stream == null) {
      task.status = TaskStatus.failed;
      _emit();
      return;
    }

    stream.listen(
      (event) {
        switch (event) {
          case VerifyDownloadProgress_Started(:final field0):
            task.totalBytes = field0.toInt();
            task.stage = 'verifying';
          case VerifyDownloadProgress_Progress(:final field0):
            task.downloadedBytes = field0.toInt();
          case VerifyDownloadProgress_CouldNotResolvePath(:final field0):
            _recordVerifyFailure(task, field0, VerifyFailure.unreadable);
          case VerifyDownloadProgress_FileNotFound(:final field0):
            _recordVerifyFailure(task, field0, VerifyFailure.missing);
          case VerifyDownloadProgress_ChecksumMismatch(:final field0):
            _recordVerifyFailure(task, field0, VerifyFailure.corrupt);
          case VerifyDownloadProgress_Finished(:final field0):
            task.chunksToRedownload = field0.toInt();
            _emit();
            return;
        }
        _emitThrottled();
      },
      onDone: () {
        if (task.chunksToRedownload == 0 && task.errorFiles.isEmpty) {
          task.status = TaskStatus.completed;
          if (task.path != null) {
            _gamesNotifier.markInstalled(gameId, task.path!);
          }
        } else {
          task.status = TaskStatus.failed;
        }
        _emit();
      },
      onError: (Object error) {
        logGogError(error);
        task.status = TaskStatus.failed;
        _emit();
      },
    );
  }

  /// Records one per-path damaged-file event — from verification (a real
  /// failure) or repair (a file repair is about to fix) — and, for
  /// verification, re-derives [ActivityTask.errorFiles] from the map's
  /// keys, which is the source of truth there. Repair leaves [ActivityTask
  /// .errorFiles] alone; it stays reserved for allocation errors. Called
  /// from a per-event switch case, so it deliberately does not call
  /// `_emitThrottled` itself; the caller does that once per event.
  void _recordVerifyFailure(
    ActivityTask task,
    String path,
    VerifyFailure kind,
  ) {
    task.verifyFailures = {...task.verifyFailures, path: kind};
    if (task.kind == TaskKind.verification) {
      task.errorFiles = task.verifyFailures.keys.toList();
    }
  }

  /// Verifies an already-installed game. Unlike [startVerification]'s
  /// "Import" caller, this may target a gameId whose previous verification
  /// task is still sitting in the registry and whose bridge stream was
  /// already fully consumed (streams are single-subscription) — both would
  /// otherwise make a re-verify silently no-op or replay a closed stream, so
  /// clear them first, same trick [startRepair] uses.
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

    final task = ActivityTask(
      gameId: gameId,
      kind: TaskKind.download,
      path: path,
      buildName: buildName,
      productIds: productIds,
    );
    state = DownloadsState({...state.tasks, gameId: task});
    _gamesNotifier.setGameStatus(gameId, GameStatus.downloading);

    final stream = await _gogState.downloadGameFiles(
      gameId,
      path,
      buildName,
      productIds,
    );
    if (stream == null) {
      task.status = TaskStatus.failed;
      _gamesNotifier.setGameStatus(gameId, GameStatus.notInstalled);
      _emit();
      return;
    }

    stream.listen(
      (event) {
        switch (event) {
          case DownloadGameProgress_Started(:final totalFiles, :final totalBytes):
            task.totalFiles = totalFiles.toInt();
            task.totalBytes = totalBytes.toInt();
            task.processedFiles = 0;
            task.stage = 'checkingFiles';
          case DownloadGameProgress_FileSizeVerification(:final checkedFiles):
            task.processedFiles = checkedFiles.toInt();
          case DownloadGameProgress_FileAllocationStarted(:final totalFiles):
            task.totalFiles = totalFiles.toInt();
            task.processedFiles = 0;
            task.stage = 'allocating';
          case DownloadGameProgress_FileAllocation(:final allocatedFiles):
            task.processedFiles = allocatedFiles.toInt();
          case DownloadGameProgress_AllocationError(:final field0):
            task.errorFiles = [...task.errorFiles, field0];
          case DownloadGameProgress_DownloadProgress(:final downloadedBytes):
            task.downloadedBytes = downloadedBytes.toInt();
            task.stage = 'downloading';
          case DownloadGameProgress_Finished():
            task.stage = 'finished';
            _emit();
            return;
        }
        _emitThrottled();
      },
      onDone: () {
        if (task.stage == 'finished') {
          task.status = TaskStatus.completed;
          if (task.path != null) {
            _gamesNotifier.markInstalled(gameId, task.path!);
          }
        } else {
          task.status = TaskStatus.failed;
          _gamesNotifier.setGameStatus(gameId, GameStatus.notInstalled);
        }
        _emit();
      },
      onError: (Object error) {
        logGogError(error);
        task.status = TaskStatus.failed;
        _gamesNotifier.setGameStatus(gameId, GameStatus.notInstalled);
        _emit();
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
    final task = ActivityTask(
      gameId: gameId,
      kind: TaskKind.repair,
      path: path,
      buildName: buildName,
      productIds: productIds,
    );
    state = DownloadsState({...state.tasks, gameId: task});

    final stream = await _gogState.repairGameFiles(
      gameId,
      path,
      buildName,
      productIds,
    );
    if (stream == null) {
      task.status = TaskStatus.failed;
      _emit();
      return;
    }

    stream.listen(
      (event) {
        switch (event) {
          case RepairGameProgress_Started(:final totalFiles, :final totalBytes):
            task.totalFiles = totalFiles.toInt();
            task.totalBytes = totalBytes.toInt();
            task.processedFiles = 0;
            task.stage = 'checkingFiles';
          case RepairGameProgress_FileSizeVerification(:final checkedFiles):
            task.processedFiles = checkedFiles.toInt();
          case RepairGameProgress_FileAllocationStarted(:final totalFiles):
            task.totalFiles = totalFiles.toInt();
            task.processedFiles = 0;
            task.stage = 'allocating';
          case RepairGameProgress_FileAllocation(:final allocatedFiles):
            task.processedFiles = allocatedFiles.toInt();
          case RepairGameProgress_AllocationError(:final field0):
            task.errorFiles = [...task.errorFiles, field0];
          case RepairGameProgress_Verification(:final checkedBytes):
            task.downloadedBytes = checkedBytes.toInt();
            task.stage = 'verifyingChunks';
          case RepairGameProgress_CouldNotResolvePath(:final field0):
            _recordVerifyFailure(task, field0, VerifyFailure.unreadable);
          case RepairGameProgress_FileNotFound(:final field0):
            _recordVerifyFailure(task, field0, VerifyFailure.missing);
          case RepairGameProgress_ChecksumMismatch(:final field0):
            _recordVerifyFailure(task, field0, VerifyFailure.corrupt);
          case RepairGameProgress_DownloadStarted(:final totalBytes):
            task.totalBytes = totalBytes.toInt();
            task.downloadedBytes = 0;
            task.stage = 'downloading';
          case RepairGameProgress_DownloadProgress(:final downloadedBytes):
            task.downloadedBytes = downloadedBytes.toInt();
          case RepairGameProgress_Finished():
            task.stage = 'finished';
            _emit();
            return;
        }
        _emitThrottled();
      },
      onDone: () {
        if (task.stage == 'finished' && task.errorFiles.isEmpty) {
          task.status = TaskStatus.completed;
          if (task.path != null) {
            _gamesNotifier.markInstalled(gameId, task.path!);
          }
        } else {
          task.status = TaskStatus.failed;
        }
        _emit();
      },
      onError: (Object error) {
        logGogError(error);
        task.status = TaskStatus.failed;
        _emit();
      },
    );
  }
}

final downloadsStateProvider =
    NotifierProvider<DownloadsNotifier, DownloadsState>(
      DownloadsNotifier.new,
      name: 'downloadsStateProvider',
    );
