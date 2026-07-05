import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:gogdl2_flutter/state/gog_state.dart';

enum TaskKind { download, verification }

enum TaskStatus { running, completed, failed }

class ActivityTask {
  final int gameId;
  final TaskKind kind;
  TaskStatus status;
  int totalFiles;
  int verifiedFiles;
  List<String> errorFiles;

  ActivityTask({
    required this.gameId,
    required this.kind,
    this.status = TaskStatus.running,
    this.totalFiles = 0,
    this.verifiedFiles = 0,
    this.errorFiles = const [],
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

  Future<void> startVerification(
    int gameId, {
    required String path,
    required String buildName,
    required List<String> productIds,
  }) async {
    if (_tasks.containsKey(gameId)) {
      return;
    }
    final task = ActivityTask(gameId: gameId, kind: TaskKind.verification);
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
        task.totalFiles = event.totalFiles.toInt();
        task.verifiedFiles = event.verifiedFiles.toInt();
        task.errorFiles = event.errorFiles;
        notifyListeners();
      },
      onDone: () {
        if (task.errorFiles.isNotEmpty) {
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
