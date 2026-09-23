import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl_flutter/gogdl_flutter.dart' hide ProtonRelease;
import 'package:lumen/common/app_paths.dart';
import 'package:lumen/models/proton_release.dart';
import 'package:lumen/state/downloads_state.dart' show TaskStatus;
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/state/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lumen/common/gog_error.dart';

/// Sentinel default for nullable [ProtonTask.copyWith] parameters, so
/// "argument omitted" (keep the existing value) can be distinguished from
/// "argument explicitly passed as `null`" (clear the field) — same pattern
/// as `ActivityTask.copyWith`'s `_unset` in downloads_state.dart.
const _unset = Object();

/// Immutable snapshot of one Proton-GE release download's progress, keyed by
/// tag name in [ProtonState.tasks]. Mirrors [ActivityTask] in
/// downloads_state.dart, but byte-only (no chunk/file bookkeeping). Updates
/// go through [copyWith]; [ProtonNotifier] is the only thing that constructs
/// new ones.
class ProtonTask {
  final String tag;
  final TaskStatus status;
  final int transferred;
  final int total;

  /// "downloading" or "extracting" — derived from [transferred]/[total],
  /// not read directly off the bridge's `ProtonDownloadProgress` (see
  /// [ProtonNotifier.downloadRelease]): extraction runs concurrently with
  /// the download, so its `extracted` events interleave with `progress`
  /// for the whole transfer rather than marking a distinct phase.
  final String? stage;

  ProtonTask({
    required this.tag,
    this.status = TaskStatus.running,
    this.transferred = 0,
    this.total = 0,
    this.stage,
  });

  /// Returns a copy with the given fields replaced. [stage] defaults to the
  /// [_unset] sentinel rather than `null`, so omitting it keeps the
  /// existing value while passing `null` explicitly clears it.
  ProtonTask copyWith({
    TaskStatus? status,
    int? transferred,
    int? total,
    Object? stage = _unset,
  }) {
    return ProtonTask(
      tag: tag,
      status: status ?? this.status,
      transferred: transferred ?? this.transferred,
      total: total ?? this.total,
      stage: identical(stage, _unset) ? this.stage : stage as String?,
    );
  }
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

  /// Commits [next] as the replacement for [current] if [current] is still
  /// the task registered for its tag — a stream whose task was replaced
  /// (e.g. a retried download after a failure) keeps delivering events to
  /// an orphaned closure-local task; this stops those stale events from
  /// clobbering whatever replaced it. Returns [next] regardless, so the
  /// caller's local variable keeps evolving for its own onDone/onError
  /// decisions even once its updates stop landing. Mirrors
  /// `DownloadsNotifier._commit` in downloads_state.dart (without the
  /// throttling — Proton downloads don't throttle emits).
  ProtonTask _commit(ProtonTask current, ProtonTask next) {
    if (identical(state.tasks[next.tag], current)) {
      state = ProtonState(
        installed: state.installed,
        defaultVersion: state.defaultVersion,
        tasks: {...state.tasks, next.tag: next},
      );
    }
    return next;
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
    var task = ProtonTask(tag: tag);
    state = ProtonState(
      installed: state.installed,
      defaultVersion: state.defaultVersion,
      tasks: {...state.tasks, tag: task},
    );

    final stream = await _gogState.downloadProtonRelease(tag, dir);
    if (stream == null) {
      _commit(task, task.copyWith(status: TaskStatus.failed));
      return;
    }

    // Set by ProtonDownloadProgress_Finished — the directory the bridge
    // actually extracted into, which sanitizes the tag for the filesystem
    // and so can differ from '$dir/$tag'. A stream that closes without it
    // is treated as a failed download, not guessed at.
    String? extractedPath;

    stream.listen(
      (event) {
        switch (event) {
          case ProtonDownloadProgress_Started(:final field0):
            task = _commit(
              task,
              task.copyWith(total: field0.toInt(), stage: 'downloading'),
            );
          case ProtonDownloadProgress_Progress(:final field0):
            final transferred = field0.toInt();
            final stage = task.total > 0 && transferred >= task.total
                ? 'extracting'
                : 'downloading';
            task = _commit(
              task,
              task.copyWith(transferred: transferred, stage: stage),
            );
          case ProtonDownloadProgress_Extracted():
            // Entries are extracted as the tarball streams in, so these
            // interleave with Progress for the whole transfer rather than
            // marking a phase — the byte counters above decide the stage.
            return;
          case ProtonDownloadProgress_Finished(:final field0):
            extractedPath = field0;
        }
      },
      onDone: () {
        final path = extractedPath;
        if (path != null && task.status != TaskStatus.failed) {
          task = _commit(task, task.copyWith(status: TaskStatus.completed));
          _install(tag, path);
        } else {
          task = _commit(task, task.copyWith(status: TaskStatus.failed));
        }
      },
      onError: (Object error) {
        logGogError(error);
        task = _commit(task, task.copyWith(status: TaskStatus.failed));
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
