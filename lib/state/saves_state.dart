import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl_flutter/gogdl_flutter.dart';
import 'package:lumen/common/app_paths.dart';
import 'package:lumen/common/gog_error.dart';
import 'package:lumen/state/downloads_state.dart' show TaskStatus;
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_state.dart';

enum SaveDirection { download, upload }

/// Sentinel default for nullable [SaveTask.copyWith] parameters, so
/// "argument omitted" (keep the existing value) can be distinguished from
/// "argument explicitly passed as `null`" (clear the field) — same pattern
/// as `ActivityTask.copyWith`'s `_unset` in downloads_state.dart.
const _unset = Object();

/// Immutable snapshot of one game's cloud save sync progress, keyed by
/// gameId in [SavesState.tasks]. A sync is a single whole-job bridge stream
/// that moves a directory of save files one at a time, so this tracks both
/// job-level counters (files, and bytes where the bridge knows them) and the
/// file currently transferring. Updates go through [copyWith]; [SavesNotifier]
/// is the only thing that constructs new ones.
class SaveTask {
  final int gameId;
  final SaveDirection direction;
  final TaskStatus status;

  /// Why the sync failed; null unless [status] is [TaskStatus.failed].
  final String? error;
  final int filesTotal;
  final int filesProcessed;

  /// Bytes moved across the whole job. [total] is only known up front for
  /// downloads — uploads leave it at 0, since the bridge reports each file's
  /// size only as that file starts.
  final int transferred;
  final int total;

  /// The file currently in flight and its own byte counters; null between
  /// files.
  final String? currentFile;
  final int fileTransferred;
  final int fileTotal;

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

  /// Returns a copy with the given fields replaced. [error] and
  /// [currentFile] default to the [_unset] sentinel rather than `null`, so
  /// omitting them keeps the existing value while passing `null` explicitly
  /// clears them.
  SaveTask copyWith({
    TaskStatus? status,
    Object? error = _unset,
    int? filesTotal,
    int? filesProcessed,
    int? transferred,
    int? total,
    Object? currentFile = _unset,
    int? fileTransferred,
    int? fileTotal,
  }) {
    return SaveTask(
      gameId: gameId,
      direction: direction,
      status: status ?? this.status,
      error: identical(error, _unset) ? this.error : error as String?,
      filesTotal: filesTotal ?? this.filesTotal,
      filesProcessed: filesProcessed ?? this.filesProcessed,
      transferred: transferred ?? this.transferred,
      total: total ?? this.total,
      currentFile: identical(currentFile, _unset)
          ? this.currentFile
          : currentFile as String?,
      fileTransferred: fileTransferred ?? this.fileTransferred,
      fileTotal: fileTotal ?? this.fileTotal,
    );
  }
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
/// Sole listener of the per-game save streams it requests from [GogState] —
/// bridge streams are single-subscription, so nothing else may listen to
/// them.
class SavesNotifier extends Notifier<SavesState> {
  late final GogState _gogState;
  late final GamesNotifier _gamesNotifier;

  @override
  SavesState build() {
    _gogState = ref.read(gogStateProvider);
    _gamesNotifier = ref.read(gamesStateProvider.notifier);
    return const SavesState.empty();
  }

  /// Commits [next] as the replacement for [current] if [current] is still
  /// the task registered for its game — a stream whose task was replaced
  /// (e.g. a finished sync's stream delivering a late error after a new
  /// sync started) keeps delivering events to an orphaned closure-local
  /// task; this stops those stale events from clobbering whatever replaced
  /// it. Returns [next] regardless, so the caller's local variable keeps
  /// evolving for its own onDone/onError decisions even once its updates
  /// stop landing. Mirrors `DownloadsNotifier._commit` in downloads_state.dart
  /// (without the throttling — saves syncs don't throttle emits).
  SaveTask _commit(SaveTask current, SaveTask next) {
    if (identical(state.tasks[next.gameId], current)) {
      state = SavesState({...state.tasks, next.gameId: next});
    }
    return next;
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
    var task = SaveTask(gameId: gameId, direction: direction);
    state = SavesState({...state.tasks, gameId: task});

    final gamesState = ref.read(gamesStateProvider);
    final buildName = gamesState.getSelectedBuild(gameId);
    final installPath = gamesState.getInstallPath(gameId);
    if (buildName == null || installPath == null) {
      _commit(
        task,
        task.copyWith(
          status: TaskStatus.failed,
          error: 'game is not installed',
        ),
      );
      return;
    }
    // The bridge needs an initialized Wine prefix and fails without one, so
    // bail out before a first launch has created it — and without creating
    // or recording a prefix dir for a sync that can't run.
    final prefixRoot =
        gamesState.getProtonPrefixPath(gameId) ?? protonPrefixDir(gameId);
    if (!Directory('$prefixRoot/pfx').existsSync()) {
      _commit(
        task,
        task.copyWith(
          status: TaskStatus.failed,
          error: 'launch the game once to set up its Wine prefix',
        ),
      );
      return;
    }
    // The bridge expands save locations under `<prefix>/drive_c`, so it wants
    // the Wine prefix Proton creates inside the compat data dir, not the
    // compat data dir itself.
    final prefix = '${_gamesNotifier.ensureProtonPrefix(gameId)}/pfx';

    final Stream<Object?>? stream;
    if (direction == SaveDirection.download) {
      stream = _gogState.downloadSaves(gameId, buildName, prefix, installPath);
    } else {
      stream = _gogState.uploadSaves(gameId, buildName, prefix, installPath);
    }
    if (stream == null) {
      _commit(
        task,
        task.copyWith(status: TaskStatus.failed, error: 'could not start the sync'),
      );
      return;
    }

    stream.listen(
      (event) {
        task = _commit(task, _apply(task, event));
      },
      onDone: () {
        // `Finished` normally marks completion first; this covers a stream
        // that closes without one.
        if (task.status == TaskStatus.running) {
          task = _commit(task, task.copyWith(status: TaskStatus.completed));
        }
      },
      onError: (Object error) {
        logGogError(error);
        task = _commit(
          task,
          task.copyWith(status: TaskStatus.failed, error: gogErrorText(error)),
        );
      },
    );
  }

  /// Pure: returns the task updated for [event], or [task] unchanged if the
  /// event doesn't affect it.
  SaveTask _apply(SaveTask task, Object? event) {
    switch (event) {
      case DownloadSavesProgress_Started(:final totalFiles, :final totalBytes):
        return task.copyWith(
          filesTotal: totalFiles.toInt(),
          total: totalBytes.toInt(),
        );
      case DownloadSavesProgress_FileStarted(:final name, :final totalBytes):
        return task.copyWith(
          currentFile: name,
          fileTotal: totalBytes.toInt(),
          fileTransferred: 0,
        );
      case DownloadSavesProgress_Progress(
        :final downloadedBytes,
        :final fileDownloadedBytes,
      ):
        return task.copyWith(
          transferred: downloadedBytes.toInt(),
          fileTransferred: fileDownloadedBytes.toInt(),
        );
      case DownloadSavesProgress_FileFinished():
        return task.copyWith(
          filesProcessed: task.filesProcessed + 1,
          currentFile: null,
        );
      case DownloadSavesProgress_Finished():
        return task.copyWith(status: TaskStatus.completed);
      case UploadSavesProgress_Started(:final totalFiles):
        return task.copyWith(filesTotal: totalFiles.toInt());
      case UploadSavesProgress_FileStarted(:final name, :final totalBytes):
        return task.copyWith(
          currentFile: name,
          fileTotal: totalBytes.toInt(),
          fileTransferred: 0,
        );
      case UploadSavesProgress_Progress(
        :final uploadedBytes,
        :final fileUploadedBytes,
      ):
        return task.copyWith(
          transferred: uploadedBytes.toInt(),
          fileTransferred: fileUploadedBytes.toInt(),
        );
      case UploadSavesProgress_FileFinished():
        return task.copyWith(
          filesProcessed: task.filesProcessed + 1,
          currentFile: null,
        );
      case UploadSavesProgress_Finished():
        return task.copyWith(status: TaskStatus.completed);
      default:
        return task;
    }
  }
}

final savesStateProvider = NotifierProvider<SavesNotifier, SavesState>(
  SavesNotifier.new,
  name: 'savesStateProvider',
);
