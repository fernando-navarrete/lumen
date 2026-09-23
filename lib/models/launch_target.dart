import 'package:flutter/foundation.dart';

/// Where a [LaunchTarget] came from.
enum LaunchTargetSource {
  /// The executable the user picked, stored as `GameConfig.executable`.
  userOverride,

  /// A `playTasks` entry from the install's `goggame-<gameId>.info`.
  gogMetadata,

  /// The `findExecutables` heuristic scan of the install directory.
  scan,
}

/// What to spawn for a game: an executable plus the working directory and
/// arguments it should run with. App-owned; not a bridge type.
class LaunchTarget {
  /// Relative to the install root, always `/`-separated.
  final String executable;

  /// Relative to the install root, or null for "the executable's parent
  /// directory".
  final String? workingDir;

  /// Passed before the user's own launch args.
  final List<String> arguments;

  final LaunchTargetSource source;

  const LaunchTarget({
    required this.executable,
    this.workingDir,
    this.arguments = const [],
    required this.source,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LaunchTarget &&
          runtimeType == other.runtimeType &&
          executable == other.executable &&
          workingDir == other.workingDir &&
          listEquals(arguments, other.arguments) &&
          source == other.source;

  @override
  int get hashCode =>
      Object.hash(executable, workingDir, Object.hashAll(arguments), source);

  @override
  String toString() =>
      'LaunchTarget($executable, workingDir: $workingDir, '
      'arguments: $arguments, source: ${source.name})';
}
