import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/app_paths.dart';
import 'package:lumen/state/downloads_state.dart' show TaskStatus;
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/state/shared_preferences_provider.dart';
import 'package:gogdl2_flutter_bridge/gogdl2_flutter_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-flight/finished progress for one Proton-GE release download, keyed by
/// tag name in [ProtonState.tasks]. Mirrors [ActivityTask] in
/// downloads_state.dart, but byte-only (no chunk/file bookkeeping) since
/// the bridge's Proton stream only ever reports transferred/total bytes.
class ProtonTask {
  final String tag;
  TaskStatus status;
  int transferred;
  int total;

  /// e.g. "downloading", "extracting", "downloaded" — see
  /// `ProtonDownloadStatus.name()` in the bridge.
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
  /// Installed versions, tag name -> the directory Proton-GE was extracted
  /// into (i.e. `<protonInstallDir()>/<tag>`).
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
  Future<void> downloadRelease(ProtonRelease release, [String? targetDir]) async {
    final tag = release.tagName();
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

    final stream = await _gogState.downloadProtonRelease(release, dir);
    if (stream == null) {
      task.status = TaskStatus.failed;
      _emit();
      return;
    }

    stream.listen(
      (event) {
        task.transferred = event.transferred.toInt();
        task.total = event.total.toInt();
        task.stage = event.status.name();
        _emit();
      },
      onDone: () {
        task.status = TaskStatus.completed;
        _install(tag, '$dir/$tag');
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
  /// disk — the user picked that location and may want to keep it).
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
      if (kDebugMode) {
        print(e);
      }
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
      if (kDebugMode) {
        print(e);
      }
      return const ProtonState.empty();
    }
  }
}

final protonStateProvider = NotifierProvider<ProtonNotifier, ProtonState>(
  ProtonNotifier.new,
  name: 'protonStateProvider',
);
