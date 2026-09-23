import 'dart:io';

import 'package:flutter/foundation.dart';

/// Test seam: when non-null, used in place of `$XDG_DATA_HOME`, so tests can
/// point every Lumen-owned path at a temp dir instead of the real
/// `~/.local/share/lumen`. See `test/helpers/temp_data_home.dart`.
@visibleForTesting
String? xdgDataHomeOverride;

/// Filesystem locations Lumen owns, e.g. Proton-GE prefixes. Not used for
/// game install directories, which are always user-chosen via `DirPicker`.
///
/// Resolves under `$XDG_DATA_HOME` when set (the XDG Base Directory spec),
/// falling back to `$HOME/.local/share` otherwise.
String lumenDataDir() {
  final xdgDataHome =
      xdgDataHomeOverride ?? Platform.environment['XDG_DATA_HOME'];
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

/// Shared Steam compat client directory passed to every launched game as
/// `STEAM_COMPAT_CLIENT_INSTALL_PATH`. Proton only needs *a* writable
/// directory here, not a real Steam install — mirrors how gogdl-cli and
/// other non-Steam Proton launchers (Lutris, Heroic) configure this.
String steamCompatClientDir() => '${lumenDataDir()}/steam';
