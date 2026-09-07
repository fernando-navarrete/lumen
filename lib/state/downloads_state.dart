import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl_flutter/gogdl_flutter.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_state.dart';

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

  // Verification only: which of [errorFiles] failed for which reason, and
  // the chunk count from the terminal `finished` event (null until then).
  // [errorFiles] is derived from this map's keys.
  Map<String, VerifyFailure> verifyFailures;
  int? chunksToRedownload;

  // Download/repair/verification progress (bytes-based) and current stage,
  // e.g. "downloading".
  int totalBytes;
  int downloadedBytes;
  String? stage;

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
    this.path,
    this.buildName,
    this.productIds = const [],
  });

  int verifyFailureCount(VerifyFailure kind) =>
      verifyFailures.values.where((f) => f == kind).length;
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
        if (kDebugMode) {
          print(error);
        }
        task.status = TaskStatus.failed;
        _emit();
      },
    );
  }

  /// Records one per-path verification failure and re-derives [ActivityTask
  /// .errorFiles] from the map's keys — the map is the source of truth.
  /// Called from a per-event switch case, so it deliberately does not call
  /// `_emitThrottled` itself; the caller does that once per event.
  void _recordVerifyFailure(
    ActivityTask task,
    String path,
    VerifyFailure kind,
  ) {
    task.verifyFailures = {...task.verifyFailures, path: kind};
    task.errorFiles = task.verifyFailures.keys.toList();
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

  Future<void> startDownload(
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
        task.totalBytes = event.totalBytes;
        task.downloadedBytes = event.downloadedBytes;
        task.errorFiles = event.errorFiles;
        task.stage = event.status;
        _emitThrottled();
      },
      onDone: () {
        if (task.errorFiles.isNotEmpty) {
          task.status = TaskStatus.failed;
          _gamesNotifier.setGameStatus(gameId, GameStatus.notInstalled);
        } else {
          task.status = TaskStatus.completed;
          if (task.path != null) {
            _gamesNotifier.markInstalled(gameId, task.path!);
          }
        }
        _emit();
      },
      onError: (Object error) {
        if (kDebugMode) {
          print(error);
        }
        task.status = TaskStatus.failed;
        _gamesNotifier.setGameStatus(gameId, GameStatus.notInstalled);
        _emit();
      },
    );
  }

  /// Dequeues a failed verification task and starts repairing the same game,
  /// tracked as a [TaskKind.repair] task in the Downloads section.
  Future<void> startRepair(int gameId) async {
    final failedTask = state.tasks[gameId];
    if (failedTask == null ||
        failedTask.path == null ||
        failedTask.buildName == null) {
      return;
    }
    final path = failedTask.path!;
    final buildName = failedTask.buildName!;
    final productIds = failedTask.productIds;

    removeTask(gameId);
    _gogState.clearVerificationStream(gameId);

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
        task.totalBytes = event.totalBytes;
        task.downloadedBytes = event.downloadedBytes;
        task.errorFiles = event.errorFiles;
        task.stage = event.status;
        _emitThrottled();
      },
      onDone: () {
        if (task.errorFiles.isNotEmpty) {
          task.status = TaskStatus.failed;
        } else {
          task.status = TaskStatus.completed;
          if (task.path != null) {
            _gamesNotifier.markInstalled(gameId, task.path!);
          }
        }
        _emit();
      },
      onError: (Object error) {
        if (kDebugMode) {
          print(error);
        }
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
