import 'dart:io';

/// Filesystem locations Lumen owns, e.g. Proton-GE prefixes. Not used for
/// game install directories, which are always user-chosen via `DirPicker`.
///
/// Resolves under `$XDG_DATA_HOME` when set (the XDG Base Directory spec),
/// falling back to `$HOME/.local/share` otherwise.
String lumenDataDir() {
  final xdgDataHome = Platform.environment['XDG_DATA_HOME'];
  final base = (xdgDataHome != null && xdgDataHome.isNotEmpty)
      ? xdgDataHome
      : '${Platform.environment['HOME']}/.local/share';
  return '$base/lumen';
}

/// The Proton prefix directory for [gameId], created on first launch.
String protonPrefixDir(int gameId) => '${lumenDataDir()}/prefixes/$gameId';

/// Default directory Proton-GE versions are installed into (each release
/// extracted to `<protonInstallDir()>/<tag>`).
String protonInstallDir() => '${lumenDataDir()}/proton';
