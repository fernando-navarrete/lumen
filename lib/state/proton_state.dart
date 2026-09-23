import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl_flutter/gogdl_flutter.dart';
import 'package:lumen/common/app_paths.dart';
import 'package:lumen/state/downloads_state.dart' show TaskStatus;
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/state/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lumen/common/gog_error.dart';

/// In-flight/finished progress for one Proton-GE release download, keyed by
/// tag name in [ProtonState.tasks]. Mirrors [ActivityTask] in
/// downloads_state.dart, but byte-only (no chunk/file bookkeeping).
class ProtonTask {
  final String tag;
  TaskStatus status;
  int transferred;
  int total;

  /// "downloading" or "extracting" — derived from [transferred]/[total],
  /// not read directly off the bridge's `ProtonDownloadProgress` (see
  /// [ProtonNotifier.downloadRelease]): extraction runs concurrently with
  /// the download, so its `extracted` events interleave with `progress`
  /// for the whole transfer rather than marking a distinct phase.
  String? stage;

  ProtonTask({
    required this.tag,
    this.status = TaskStatus.running,
    this.transferred = 0,
    this.total = 0,
    this.stage,
  });
}

/// Immutable snapshot of installed Proton-GE versions, the chosen global
/// default, and any in-flight downloads. Read-only — mutations go through
/// [ProtonNotifier] via `protonStateProvider.notifier`.
class ProtonState {
  /// Installed versions, tag name -> the directory the bridge reported
  /// extracting into (`ProtonDownloadProgress.finished`), normally
  /// `<targetDir>/<tag>` with the tag sanitized for the filesystem.
  final Map<String, String> installed;
  final String? defaultVersion;
  final Map<String, ProtonTask> tasks;

  const ProtonState({
    required this.installed,
    required this.defaultVersion,
    required this.tasks,
  });

  const ProtonState.empty()
    : installed = const {},
      defaultVersion = null,
      tasks = const {};

  List<String> get installedTags => installed.keys.toList();

  bool isInstalled(String tag) => installed.containsKey(tag);

  String? pathFor(String tag) => installed[tag];

  ProtonTask? taskFor(String tag) => tasks[tag];
}

/// Manages Proton-GE releases: fetching the list from GitHub, downloading
/// and extracting a chosen release (tracked the same way as game
/// downloads/repairs — see [DownloadsNotifier]), and persisting the set of
/// installed versions plus the app-wide default to SharedPreferences.
class ProtonNotifier extends Notifier<ProtonState> {
  late final GogState _gogState;
  late final SharedPreferences _prefs;

  static const _installedKey = 'protonInstalled';
  static const _defaultKey = 'protonDefault';

  @override
  ProtonState build() {
    _gogState = ref.read(gogStateProvider);
    _prefs = ref.read(sharedPreferencesProvider);
    return _load();
  }

  void _emit() {
    state = ProtonState(
      installed: state.installed,
      defaultVersion: state.defaultVersion,
      tasks: {...state.tasks},
    );
  }

  Future<List<ProtonRelease>?> fetchReleases(int page) {
    return _gogState.getProtonReleases(page);
  }

  /// Downloads and extracts [release] into [targetDir] (defaulting to
  /// [protonInstallDir], the Lumen-owned Proton directory, when omitted),
  /// tracking progress in [ProtonState.tasks] under the release's tag name.
  /// On success, registers the extracted install directory and — if no
  /// default is set yet — makes this release the default. Safe to call
  /// again for a previously failed download (e.g. a "Retry" tap); a running
  /// or already-installed release is left alone.
  Future<void> downloadRelease(
    ProtonRelease release, [
    String? targetDir,
  ]) async {
    final tag = release.tagName;
    if (state.installed.containsKey(tag)) {
      return;
    }
    final existingTask = state.tasks[tag];
    if (existingTask != null && existingTask.status != TaskStatus.failed) {
      return;
    }
    if (existingTask != null) {
      // Bridge streams are single-subscription, so a failed attempt's
      // stream can't be re-listened to — drop the cache before retrying.
      _gogState.clearProtonDownloadStream(tag);
    }
    final dir = targetDir ?? protonInstallDir();
    Directory(dir).createSync(recursive: true);
    final task = ProtonTask(tag: tag);
    state = ProtonState(
      installed: state.installed,
      defaultVersion: state.defaultVersion,
      tasks: {...state.tasks, tag: task},
    );

    final stream = await _gogState.downloadProtonRelease(tag, dir);
    if (stream == null) {
      task.status = TaskStatus.failed;
      _emit();
      return;
    }

    // Set by ProtonDownloadProgress_Finished — the directory the bridge
    // actually extracted into, which sanitizes the tag for the filesystem
    // and so can differ from '$dir/$tag'.
    String? extractedPath;

    stream.listen(
      (event) {
        switch (event) {
          case ProtonDownloadProgress_Started(:final field0):
            task.total = field0.toInt();
            task.stage = 'downloading';
          case ProtonDownloadProgress_Progress(:final field0):
            task.transferred = field0.toInt();
            task.stage = task.total > 0 && task.transferred >= task.total
                ? 'extracting'
                : 'downloading';
          case ProtonDownloadProgress_Extracted():
            // Entries are extracted as the tarball streams in, so these
            // interleave with Progress for the whole transfer rather than
            // marking a phase — the byte counters above decide the stage.
            return;
          case ProtonDownloadProgress_Finished(:final field0):
            extractedPath = field0;
        }
        _emit();
      },
      onDone: () {
        task.status = TaskStatus.completed;
        _install(tag, extractedPath ?? '$dir/$tag');
        _emit();
      },
      onError: (Object error) {
        logGogError(error);
        task.status = TaskStatus.failed;
        _emit();
      },
    );
  }

  void _install(String tag, String path) {
    final installed = {...state.installed, tag: path};
    final defaultVersion = state.defaultVersion ?? tag;
    state = ProtonState(
      installed: installed,
      defaultVersion: defaultVersion,
      tasks: state.tasks,
    );
    _persist();
  }

  void setDefault(String tag) {
    if (!state.installed.containsKey(tag)) {
      return;
    }
    state = ProtonState(
      installed: state.installed,
      defaultVersion: tag,
      tasks: state.tasks,
    );
    _persist();
  }

  /// Drops [tag] from the installed registry (does not delete the files on
  /// disk — the user picked that location and may want to keep it). Games
  /// pinned to [tag] have their override cleared so they fall back to the
  /// global default instead of failing at launch.
  void removeVersion(String tag) {
    final installed = {...state.installed}..remove(tag);
    final defaultVersion = state.defaultVersion == tag
        ? null
        : state.defaultVersion;
    state = ProtonState(
      installed: installed,
      defaultVersion: defaultVersion,
      tasks: state.tasks,
    );
    _persist();
    ref.read(gamesStateProvider.notifier).clearProtonVersion(tag);
  }

  /// Resets in-memory state to empty without touching disk — call after
  /// something else (e.g. the debug "Clear SharedPreferences" button) has
  /// already wiped the underlying prefs, so this notifier's state doesn't
  /// keep reporting versions as installed that were just cleared.
  void resetToEmpty() {
    state = const ProtonState.empty();
  }

  void _persist() {
    try {
      _prefs.setString(_installedKey, jsonEncode(state.installed));
      if (state.defaultVersion != null) {
        _prefs.setString(_defaultKey, state.defaultVersion!);
      } else {
        _prefs.remove(_defaultKey);
      }
    } catch (e) {
      logGogError(e);
    }
  }

  /// Loads the installed-versions registry and default version synchronously
  /// from the already-resolved [_prefs] instance. Called from [build] so the
  /// notifier never briefly reports "no versions installed" while a real
  /// async load is still in flight — that race previously caused spurious
  /// "Proton-GE version is no longer installed" errors at launch when the UI
  /// read state before the old fire-and-forget load had resolved.
  ProtonState _load() {
    try {
      final installedJson = _prefs.getString(_installedKey);
      final installed = installedJson != null
          ? (jsonDecode(installedJson) as Map<String, dynamic>).map(
              (tag, path) => MapEntry(tag, path as String),
            )
          : <String, String>{};
      final defaultVersion = _prefs.getString(_defaultKey);
      return ProtonState(
        installed: installed,
        defaultVersion: defaultVersion,
        tasks: const {},
      );
    } catch (e) {
      logGogError(e);
      return const ProtonState.empty();
    }
  }
}

final protonStateProvider = NotifierProvider<ProtonNotifier, ProtonState>(
  ProtonNotifier.new,
  name: 'protonStateProvider',
);
