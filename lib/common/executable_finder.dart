import 'dart:io';

/// Directory names (case-insensitive substring match) skipped while
/// scanning for launchable executables — installers/redistributables ship
/// alongside the actual game but should never be offered as launch
/// candidates. Mirrors gogdl-cli's `find_executables` skip-list.
const _skippedDirSubstrings = [
  'support',
  '__support',
  'directx',
  'redist',
  'vcredist',
  '_commonredist',
];

/// Executable filename substrings (case-insensitive) skipped for the same
/// reason — uninstallers, setup wizards, crash reporters, and runtime
/// installers rather than the game itself.
const _skippedExeSubstrings = [
  'unins',
  'setup',
  'install',
  'crash',
  'report',
  'vc_redist',
  'dxsetup',
  'dotnet',
];

/// Recursively scans [installPath] for launchable `.exe` files, applying
/// gogdl-cli's skip-lists to filter out installers/redistributables/
/// uninstallers. Returns paths relative to [installPath], sorted and
/// deduplicated. Safe to call even if [installPath] doesn't exist (returns
/// an empty list).
List<String> findExecutables(String installPath) {
  final root = Directory(installPath);
  if (!root.existsSync()) {
    return const [];
  }

  final found = <String>{};
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    if (!entity.path.toLowerCase().endsWith('.exe')) {
      continue;
    }

    final relative = entity.path
        .substring(root.path.length)
        .replaceFirst(RegExp(r'^[/\\]+'), '');
    final relativeLower = relative.toLowerCase();

    final inSkippedDir = _skippedDirSubstrings.any(
      (skip) => relativeLower.contains(skip),
    );
    if (inSkippedDir) {
      continue;
    }

    final fileName = relativeLower.split(RegExp(r'[/\\]')).last;
    final isSkippedExe = _skippedExeSubstrings.any(
      (skip) => fileName.contains(skip),
    );
    if (isSkippedExe) {
      continue;
    }

    found.add(relative);
  }

  final result = found.toList()..sort();
  return result;
}
