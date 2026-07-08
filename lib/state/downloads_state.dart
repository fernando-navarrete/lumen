import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:gogdl2_flutter/state/gog_state.dart';

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

/// Central registry of in-flight/finished download & verification tasks.
///
/// The bridge's verification stream is single-subscription, and [GogState]
/// caches one stream per game, so this class must be the sole listener —
/// any UI that needs progress reads it from here instead of the raw stream.
class DownloadsState extends ChangeNotifier {
  final GogState _gogState;
  final Map<int, ActivityTask> _tasks = {};

  DownloadsState(this._gogState);

  List<ActivityTask> get verificationTasks => _tasks.values
      .where((task) => task.kind == TaskKind.verification)
      .toList();

  List<ActivityTask> get downloadTasks =>
      _tasks.values.where((task) => task.kind == TaskKind.download).toList();

  List<ActivityTask> get repairTasks =>
      _tasks.values.where((task) => task.kind == TaskKind.repair).toList();

  /// Removes a task from the registry, e.g. to dequeue a failed verification
  /// before starting a repair for the same game.
  void removeTask(int gameId) {
    _tasks.remove(gameId);
    notifyListeners();
  }

  Future<void> startVerification(
    int gameId, {
    required String path,
    required String buildName,
    required List<String> productIds,
  }) async {
    if (_tasks.containsKey(gameId)) {
      return;
    }
    final task = ActivityTask(
      gameId: gameId,
      kind: TaskKind.verification,
      path: path,
      buildName: buildName,
      productIds: productIds,
    );
    _tasks[gameId] = task;
    notifyListeners();

    final stream = await _gogState.verifyGameFiles(
      gameId,
      path,
      buildName,
      productIds,
    );
    if (stream == null) {
      task.status = TaskStatus.failed;
      notifyListeners();
      return;
    }

    stream.listen(
      (event) {
        task.totalChunks = event.totalChunks.toInt();
        task.verifiedChunks = event.verifiedChunks.toInt();
        task.errorChunks = event.errorChunks;
        notifyListeners();
      },
      onDone: () {
        if (task.errorChunks.isNotEmpty) {
          task.status = TaskStatus.failed;
        } else {
          task.status = TaskStatus.completed;
        }
        notifyListeners();
      },
      onError: (Object error) {
        if (kDebugMode) {
          print(error);
        }
        task.status = TaskStatus.failed;
        notifyListeners();
      },
    );
  }

  /// Dequeues a failed verification task and starts repairing the same game,
  /// tracked as a [TaskKind.repair] task in the Downloads section.
  Future<void> startRepair(int gameId) async {
    final failedTask = _tasks[gameId];
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
    _tasks[gameId] = task;
    notifyListeners();

    final stream = await _gogState.repairGameFiles(
      gameId,
      path,
      buildName,
      productIds,
    );
    if (stream == null) {
      task.status = TaskStatus.failed;
      notifyListeners();
      return;
    }

    stream.listen(
      (event) {
        task.totalBytes = event.totalBytes.toInt();
        task.downloadedBytes = event.downloadedBytes.toInt();
        task.errorChunks = event.errorFiles;
        task.stage = event.status.name();
        notifyListeners();
      },
      onDone: () {
        if (task.errorChunks.isNotEmpty) {
          task.status = TaskStatus.failed;
        } else {
          task.status = TaskStatus.completed;
        }
        notifyListeners();
      },
      onError: (Object error) {
        if (kDebugMode) {
          print(error);
        }
        task.status = TaskStatus.failed;
        notifyListeners();
      },
    );
  }
}

final downloadsStateProvider = ChangeNotifierProvider<DownloadsState>((ref) {
  return DownloadsState(ref.watch(gogStateProvider));
}, name: 'downloadsStateProvider');
