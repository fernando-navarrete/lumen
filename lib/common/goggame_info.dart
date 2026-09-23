import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/launch_target.dart';
import 'gog_error.dart';
import 'shell_words.dart';

/// One launchable `.exe` `FileTask` from a `goggame-<id>.info` `playTasks`
/// list, already normalized and confirmed to exist on disk.
class _PlayTask {
  final String? name;
  final String? category;
  final bool isPrimary;
  final LaunchTarget target;

  const _PlayTask({
    required this.name,
    required this.category,
    required this.isPrimary,
    required this.target,
  });

  bool get isGame => category == 'game';
}

/// Resolves the task a game should be launched with from the install's
/// `goggame-<gameId>.info`, or null if there's no usable one (no file,
/// unparseable, or no listed `.exe` exists on disk), so the caller falls
/// back to the `findExecutables` scan.
///
/// Among the `.exe` `FileTask`s that exist on disk, this picks:
/// 1. the `isPrimary` task, if its `category` is `game`,
/// 2. otherwise the first `category: game` task, hidden or not,
/// 3. otherwise the primary task (typically a launcher).
///
/// The primary task is very often a `category: launcher` exe
/// (`REDprelauncher.exe`, `launcher.exe`, ...) with the real game listed as
/// a hidden `game` task. A launcher makes `proton run` return while the game
/// keeps running, which would make "exited", logs and stopping the game
/// meaningless, so the game task wins. A task with no `category` at all
/// counts as "not a game".
Future<LaunchTarget?> readPrimaryPlayTask(
  String installPath,
  int gameId,
) async {
  final tasks = await _readPlayTasks(installPath, gameId);
  final primary = tasks.where((t) => t.isPrimary).firstOrNull;
  if (primary != null && primary.isGame) {
    return primary.target;
  }
  final firstGame = tasks.where((t) => t.isGame).firstOrNull;
  return firstGame?.target ?? primary?.target;
}

/// Every named `.exe` `FileTask` in the install's `goggame-<gameId>.info`
/// that exists on disk, in file order, launchers and uncategorized tasks
/// included, so a user can pick one explicitly.
Future<List<({String name, LaunchTarget target})>> listPlayTasks(
  String installPath,
  int gameId,
) async {
  final tasks = await _readPlayTasks(installPath, gameId);
  return [
    for (final task in tasks)
      if (task.name != null && task.name!.isNotEmpty)
        (name: task.name!, target: task.target),
  ];
}

/// Reads exactly `<installPath>/goggame-<gameId>.info`. It always sits at the
/// install root, but the root also holds each DLC's own `.info` (with empty
/// `playTasks`) and sometimes other products' files, so this never globs for
/// `goggame-*.info`.
///
/// Never throws: any read or parse failure is logged and gives `[]`.
///
/// Ignored task fields: `languages`, `osBitness`, `compatibilityFlags`,
/// `runAsAdmin`, `isHidden`, `icon`, `additionalPaths`.
Future<List<_PlayTask>> _readPlayTasks(String installPath, int gameId) async {
  final file = File(p.join(installPath, 'goggame-$gameId.info'));
  try {
    if (!await file.exists()) {
      return const [];
    }
    var content = await file.readAsString();
    if (content.startsWith('﻿')) {
      content = content.substring(1);
    }
    final json = jsonDecode(content);
    final rawTasks = json is Map<String, dynamic> ? json['playTasks'] : null;
    if (rawTasks is! List) {
      return const [];
    }

    final tasks = <_PlayTask>[];
    for (final raw in rawTasks) {
      final task = await _parseTask(installPath, raw);
      if (task != null) {
        tasks.add(task);
      }
    }
    return tasks;
  } catch (e, st) {
    logGogError(e, st);
    return const [];
  }
}

Future<_PlayTask?> _parseTask(String installPath, Object? raw) async {
  if (raw is! Map<String, dynamic> || raw['type'] != 'FileTask') {
    return null;
  }
  final rawPath = raw['path'];
  if (rawPath is! String) {
    return null;
  }
  final executable = _normalizeRelative(rawPath);
  if (executable == null || !executable.toLowerCase().endsWith('.exe')) {
    return null;
  }

  final rawWorkingDir = raw['workingDir'];
  String? workingDir;
  if (rawWorkingDir is String && rawWorkingDir.trim().isNotEmpty) {
    workingDir = _normalizeRelative(rawWorkingDir);
    if (workingDir == null) {
      return null;
    }
  }

  // Tasks can point at files that aren't there (a stale or partial install).
  if (!await File(p.join(installPath, executable)).exists()) {
    return null;
  }

  final rawArguments = raw['arguments'];
  final name = raw['name'];
  final category = raw['category'];
  return _PlayTask(
    name: name is String ? name : null,
    category: category is String ? category : null,
    isPrimary: raw['isPrimary'] == true,
    target: LaunchTarget(
      executable: executable,
      workingDir: workingDir,
      arguments: rawArguments is String ? _splitArguments(rawArguments) : [],
      source: LaunchTargetSource.gogMetadata,
    ),
  );
}

/// Normalizes a `.info` path (which mixes `\` and `/` and can contain `//`)
/// to a `/`-separated path relative to the install root, or null if it's
/// absolute or escapes the root.
String? _normalizeRelative(String raw) {
  final normalized = p.posix.normalize(raw.replaceAll(r'\', '/'));
  if (normalized == '.' ||
      p.posix.isAbsolute(normalized) ||
      normalized == '..' ||
      normalized.startsWith('../')) {
    return null;
  }
  return normalized;
}

/// Splits a task's `arguments` string the same way the user's launch args
/// are split. GOG writes Windows-style quoting (`--launcher-fallback="DirectX
/// 11"`), which `splitShellWords` handles; a bare Windows path with `\`
/// outside quotes would have its backslashes eaten as escapes, but none has
/// been seen. A string that doesn't parse falls back to a whitespace split
/// rather than dropping the task.
List<String> _splitArguments(String raw) {
  try {
    return splitShellWords(raw);
  } on FormatException {
    final trimmed = raw.trim();
    return trimmed.isEmpty ? [] : trimmed.split(RegExp(r'\s+'));
  }
}
