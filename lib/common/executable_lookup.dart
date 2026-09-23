import 'dart:io';

import 'package:path/path.dart' as p;

/// Whether [path] is a regular file (symlinks followed) with at least one
/// executable bit set. Used to validate the Proton binary and launch-wrapper
/// candidates before spawning them, and reused by `stopGame`'s `wineserver`
/// lookup and any future prefix tooling.
bool isExecutableFile(String path) {
  final stat = FileStat.statSync(path);
  if (stat.type != FileSystemEntityType.file) {
    return false;
  }
  // Unix permission bits: owner/group/other execute is 0o100/0o010/0o001,
  // i.e. bits 0x40/0x08/0x01 — 0x49 covers all three regardless of who
  // Lumen runs as.
  return stat.mode & 0x49 != 0;
}

/// Resolves [command] the way a shell would when about to spawn it directly
/// (i.e. without going through a shell): a name containing `/` is resolved
/// against [cwd] (defaulting to the current directory) and returned only if
/// it's an executable file there; a bare name is looked up in each `:`
/// separated entry of [pathEnv], in order, returning the first executable
/// match. Returns `null` if nothing executable is found. Empty entries in
/// [pathEnv] are skipped (a shell treats an empty `PATH` entry as `.`, but
/// that's not the behavior wanted here for a missing wrapper).
String? resolveExecutable(String command, {required String? pathEnv, String? cwd}) {
  if (command.contains('/')) {
    final resolved = p.isAbsolute(command)
        ? command
        : p.join(cwd ?? Directory.current.path, command);
    return isExecutableFile(resolved) ? resolved : null;
  }

  for (final dir in (pathEnv ?? '').split(':')) {
    if (dir.isEmpty) continue;
    final candidate = p.join(dir, command);
    if (isExecutableFile(candidate)) {
      return candidate;
    }
  }
  return null;
}
