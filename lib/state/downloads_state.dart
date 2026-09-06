import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_state.dart';

enum TaskKind { download, verification, repair }

enum TaskStatus { running, completed, failed }

class ActivityTask {
  final int gameId;
  final TaskKind kind;
  TaskStatus status;
  int totalChunks;
  int verifiedChunks;
  List<String> errorChunks;

  // Repair progress (bytes-based) and current stage, e.g. "downloading".
  int totalBytes;
  int downloadedBytes;
  String? stage;

  // Launch params, persisted so a repair can be started later from the card.
  String? path;
  String? buildName;
  List<String> productIds;

  ActivityTask({
    required this.gameId,
    required this.kind,
    this.status = TaskStatus.running,
    this.totalChunks = 0,
    this.verifiedChunks = 0,
    this.errorChunks = const [],
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.stage,
    this.path,
    this.buildName,
    this.productIds = const [],
  });
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
    required List<String> productIds,
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
        task.totalChunks = event.totalChunks;
        task.verifiedChunks = event.verifiedChunks;
        task.totalBytes = event.totalBytes;
        task.downloadedBytes = event.verifiedBytes;
        task.errorChunks = event.errorChunks;
        task.stage = event.status;
        _emitThrottled();
      },
      onDone: () {
        if (task.errorChunks.isNotEmpty) {
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
    required List<String> productIds,
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
    required List<String> productIds,
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
        task.errorChunks = event.errorFiles;
        task.stage = event.status;
        _emitThrottled();
      },
      onDone: () {
        if (task.errorChunks.isNotEmpty) {
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
        task.errorChunks = event.errorFiles;
        task.stage = event.status;
        _emitThrottled();
      },
      onDone: () {
        if (task.errorChunks.isNotEmpty) {
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
