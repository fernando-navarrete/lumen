import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/save_paths.dart';
import 'package:lumen/state/downloads_state.dart' show TaskStatus;
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:gogdl2_flutter_bridge/gogdl2_flutter_bridge.dart';

enum SaveDirection { download, upload }

/// In-flight/finished progress for one game's cloud save sync, keyed by
/// gameId in [SavesState.tasks]. Mirrors [ProtonTask] (proton_state.dart) —
/// byte-only progress for the file currently transferring — plus a
/// file-count pair since a sync moves a whole directory of save files one
/// at a time rather than a single archive.
class SaveTask {
  final int gameId;
  final SaveDirection direction;
  TaskStatus status;
  int filesTotal;
  int filesProcessed;
  int transferred;
  int total;

  /// e.g. "downloading"/"downloaded" or "uploading"/"uploaded" — see
  /// `SaveDownloadStatus.name()`/`SaveUploadStatus.name()` in the bridge.
  String? stage;
  List<String> errorFiles;

  SaveTask({
    required this.gameId,
    required this.direction,
    this.status = TaskStatus.running,
    this.filesTotal = 0,
    this.filesProcessed = 0,
    this.transferred = 0,
    this.total = 0,
    this.stage,
    this.errorFiles = const [],
  });
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
/// the game's local save directory, or uploading every local save file to
/// the cloud. There's no automatic conflict resolution — the bridge exposes
/// no remote timestamp/hash, so these are two explicit, user-triggered
/// directions rather than a single merge. Progress is tracked the same way
/// as downloads/repairs/Proton downloads — see [SaveTask].
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

  Future<void> downloadSaves(int gameId) => _sync(gameId, SaveDirection.download);

  Future<void> uploadSaves(int gameId) => _sync(gameId, SaveDirection.upload);

  Future<void> _sync(int gameId, SaveDirection direction) async {
    if (!_canStart(gameId)) {
      return;
    }
    final task = SaveTask(gameId: gameId, direction: direction);
    state = SavesState({...state.tasks, gameId: task});

    try {
      final gamesState = ref.read(gamesStateProvider);
      final installPath = gamesState.getInstallPath(gameId);
      if (installPath == null) {
        task.status = TaskStatus.failed;
        _emit();
        return;
      }
      final prefixPath = _gamesNotifier.ensureProtonPrefix(gameId);

      final authIds = await _gogState.getSaveAuthIds(gameId);
      if (authIds == null) {
        task.status = TaskStatus.failed;
        _emit();
        return;
      }
      final config = await _gogState.getSaveRemoteConfig(authIds.clientId);
      if (config == null || !config.isSupported()) {
        task.status = TaskStatus.failed;
        _emit();
        return;
      }
      final (knownFolder, relativePath) = config.localPath();
      final root = resolveSaveRoot(
        knownFolder,
        relativePath,
        prefixPath: prefixPath,
        installPath: installPath,
      );

      if (direction == SaveDirection.download) {
        await _downloadAll(task, authIds, root);
      } else {
        await _uploadAll(task, authIds, root);
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      task.status = TaskStatus.failed;
      _emit();
    }
  }

  Future<void> _downloadAll(
    SaveTask task,
    SaveAuthIds authIds,
    String root,
  ) async {
    final files = await _gogState.getSaveFileList(
      authIds.clientId,
      authIds.clientSecret,
    );
    if (files == null) {
      task.status = TaskStatus.failed;
      _emit();
      return;
    }
    task.filesTotal = files.length;
    _emit();

    final errorFiles = <String>[];
    for (final file in files) {
      final path = '$root/${file.path()}';
      final completer = Completer<void>();
      _gogState
          .downloadSaveFile(
            saveFile: file,
            clientId: authIds.clientId,
            clientSecret: authIds.clientSecret,
            path: path,
          )
          .listen(
            (event) {
              task.transferred = event.transferred.toInt();
              task.total = event.total.toInt();
              task.stage = event.status.name();
              _emit();
            },
            onDone: () => completer.complete(),
            onError: (Object error) {
              if (kDebugMode) {
                print(error);
              }
              errorFiles.add(file.path());
              completer.complete();
            },
          );
      await completer.future;
      task.filesProcessed++;
      _emit();
    }

    task.errorFiles = errorFiles;
    task.status = errorFiles.isEmpty ? TaskStatus.completed : TaskStatus.failed;
    _emit();
  }

  Future<void> _uploadAll(SaveTask task, SaveAuthIds authIds, String root) async {
    final relativePaths = listLocalSaveFiles(root);
    task.filesTotal = relativePaths.length;
    _emit();

    final errorFiles = <String>[];
    for (final relativePath in relativePaths) {
      final path = '$root/$relativePath';
      final completer = Completer<void>();
      _gogState
          .uploadSaveFile(
            clientId: authIds.clientId,
            clientSecret: authIds.clientSecret,
            path: path,
            urlPath: relativePath,
          )
          .listen(
            (event) {
              task.transferred = event.transferred.toInt();
              task.total = event.total.toInt();
              task.stage = event.status.name();
              _emit();
            },
            onDone: () => completer.complete(),
            onError: (Object error) {
              if (kDebugMode) {
                print(error);
              }
              errorFiles.add(relativePath);
              completer.complete();
            },
          );
      await completer.future;
      task.filesProcessed++;
      _emit();
    }

    task.errorFiles = errorFiles;
    task.status = errorFiles.isEmpty ? TaskStatus.completed : TaskStatus.failed;
    _emit();
  }
}

final savesStateProvider = NotifierProvider<SavesNotifier, SavesState>(
  SavesNotifier.new,
  name: 'savesStateProvider',
);
