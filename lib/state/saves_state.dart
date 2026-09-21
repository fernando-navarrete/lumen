import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl_flutter/gogdl_flutter.dart';
import 'package:lumen/common/gog_error.dart';
import 'package:lumen/state/downloads_state.dart' show TaskStatus;
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_state.dart';

enum SaveDirection { download, upload }

/// In-flight/finished progress for one game's cloud save sync, keyed by
/// gameId in [SavesState.tasks]. A sync is a single whole-job bridge stream
/// that moves a directory of save files one at a time, so this tracks both
/// job-level counters (files, and bytes where the bridge knows them) and the
/// file currently transferring.
class SaveTask {
  final int gameId;
  final SaveDirection direction;
  TaskStatus status;

  /// Why the sync failed; null unless [status] is [TaskStatus.failed].
  String? error;
  int filesTotal;
  int filesProcessed;

  /// Bytes moved across the whole job. [total] is only known up front for
  /// downloads — uploads leave it at 0, since the bridge reports each file's
  /// size only as that file starts.
  int transferred;
  int total;

  /// The file currently in flight and its own byte counters; null between
  /// files.
  String? currentFile;
  int fileTransferred;
  int fileTotal;

  SaveTask({
    required this.gameId,
    required this.direction,
    this.status = TaskStatus.running,
    this.error,
    this.filesTotal = 0,
    this.filesProcessed = 0,
    this.transferred = 0,
    this.total = 0,
    this.currentFile,
    this.fileTransferred = 0,
    this.fileTotal = 0,
  });

  /// Download knows a real job byte total; upload only learns each file's
  /// size as it starts, so its bar counts files instead. Null until the
  /// first `Started` event, i.e. render indeterminate.
  double? get progress => direction == SaveDirection.download
      ? (total > 0 ? transferred / total : null)
      : (filesTotal > 0 ? filesProcessed / filesTotal : null);

  /// `Started` reported zero files — the game has no cloud saves to move.
  bool get isEmpty => status == TaskStatus.completed && filesTotal == 0;
}

/// Immutable snapshot of in-flight/finished cloud save syncs, keyed by
/// gameId. Read-only — mutations go through [SavesNotifier] via
/// `savesStateProvider.notifier`.
class SavesState {
  final Map<int, SaveTask> tasks;

  const SavesState(this.tasks);

  const SavesState.empty() : tasks = const {};

  SaveTask? taskFor(int gameId) => tasks[gameId];
}

/// Manages cloud save sync for games: downloading every remote save file to
/// the game's local save directories, or uploading every local save file to
/// the cloud. The bridge resolves the save locations itself from the Wine
/// prefix and install path. There's no automatic conflict resolution, so
/// these are two explicit, user-triggered directions rather than a single
/// merge. The bridge doesn't retry, so a failure aborts the whole job.
///
/// Sole owner of the per-game save streams cached in [GogState] — bridge
/// streams are single-subscription, so nothing else may listen to them.
class SavesNotifier extends Notifier<SavesState> {
  late final GogState _gogState;
  late final GamesNotifier _gamesNotifier;

  @override
  SavesState build() {
    _gogState = ref.read(gogStateProvider);
    _gamesNotifier = ref.read(gamesStateProvider.notifier);
    return const SavesState.empty();
  }

  void _emit() {
    state = SavesState({...state.tasks});
  }

  bool _canStart(int gameId) {
    final existing = state.tasks[gameId];
    return existing == null || existing.status != TaskStatus.running;
  }

  Future<void> downloadSaves(int gameId) =>
      _sync(gameId, SaveDirection.download);

  Future<void> uploadSaves(int gameId) => _sync(gameId, SaveDirection.upload);

  Future<void> _sync(int gameId, SaveDirection direction) async {
    if (!_canStart(gameId)) {
      return;
    }
    final task = SaveTask(gameId: gameId, direction: direction);
    state = SavesState({...state.tasks, gameId: task});

    final gamesState = ref.read(gamesStateProvider);
    final buildName = gamesState.getSelectedBuild(gameId);
    final installPath = gamesState.getInstallPath(gameId);
    if (buildName == null || installPath == null) {
      task.status = TaskStatus.failed;
      task.error = 'game is not installed';
      _emit();
      return;
    }
    // The bridge expands save locations under `<prefix>/drive_c`, so it wants
    // the Wine prefix Proton creates inside the compat data dir, not the
    // compat data dir itself.
    final prefix = '${_gamesNotifier.ensureProtonPrefix(gameId)}/pfx';

    // A finished or failed stream can't be re-listened to, so drop the
    // cached one before every run.
    final Stream<Object?>? stream;
    if (direction == SaveDirection.download) {
      _gogState.clearSaveDownloadStream(gameId);
      stream = await _gogState.downloadSaves(
        gameId,
        buildName,
        prefix,
        installPath,
      );
    } else {
      _gogState.clearSaveUploadStream(gameId);
      stream = await _gogState.uploadSaves(
        gameId,
        buildName,
        prefix,
        installPath,
      );
    }
    if (stream == null) {
      task.status = TaskStatus.failed;
      task.error = 'could not start the sync';
      _emit();
      return;
    }

    stream.listen(
      (event) {
        _apply(task, event);
        _emit();
      },
      onDone: () {
        // `Finished` normally marks completion first; this covers a stream
        // that closes without one.
        if (task.status == TaskStatus.running) {
          task.status = TaskStatus.completed;
        }
        _emit();
      },
      onError: (Object error) {
        logGogError(error);
        task.status = TaskStatus.failed;
        task.error = gogErrorText(error);
        _emit();
      },
    );
  }

  void _apply(SaveTask task, Object? event) {
    switch (event) {
      case DownloadSavesProgress_Started(:final totalFiles, :final totalBytes):
        task.filesTotal = totalFiles.toInt();
        task.total = totalBytes.toInt();
      case DownloadSavesProgress_FileStarted(:final name, :final totalBytes):
        task.currentFile = name;
        task.fileTotal = totalBytes.toInt();
        task.fileTransferred = 0;
      case DownloadSavesProgress_Progress(
        :final downloadedBytes,
        :final fileDownloadedBytes,
      ):
        task.transferred = downloadedBytes.toInt();
        task.fileTransferred = fileDownloadedBytes.toInt();
      case DownloadSavesProgress_FileFinished():
        task.filesProcessed++;
        task.currentFile = null;
      case DownloadSavesProgress_Finished():
        task.status = TaskStatus.completed;
      case UploadSavesProgress_Started(:final totalFiles):
        task.filesTotal = totalFiles.toInt();
      case UploadSavesProgress_FileStarted(:final name, :final totalBytes):
        task.currentFile = name;
        task.fileTotal = totalBytes.toInt();
        task.fileTransferred = 0;
      case UploadSavesProgress_Progress(
        :final uploadedBytes,
        :final fileUploadedBytes,
      ):
        task.transferred = uploadedBytes.toInt();
        task.fileTransferred = fileUploadedBytes.toInt();
      case UploadSavesProgress_FileFinished():
        task.filesProcessed++;
        task.currentFile = null;
      case UploadSavesProgress_Finished():
        task.status = TaskStatus.completed;
      default:
        break;
    }
  }
}

final savesStateProvider = NotifierProvider<SavesNotifier, SavesState>(
  SavesNotifier.new,
  name: 'savesStateProvider',
);
