import 'dart:io';

/// Base directories (relative to the Wine prefix's `pfx/drive_c`) that the
/// bridge's known-folder keys map onto. Games run under Proton, so every
/// Windows "known folder" except `INSTALLATION_PATH` resolves inside the
/// game's prefix rather than the host filesystem. Note the actual Wine
/// prefix lives at `<prefix>/pfx` — Proton creates it there on first run
/// (see `LaunchNotifier` in `state/launch_state.dart`) — not directly under
/// `<prefix>`.
const Map<String, String> _knownFolderPrefixPaths = {
  'Saved Games': 'users/steamuser/Saved Games',
  'Documents': 'users/steamuser/Documents',
  'Desktop': 'users/steamuser/Desktop',
  'AppData/Roaming': 'users/steamuser/AppData/Roaming',
  'AppData/Local': 'users/steamuser/AppData/Local',
  'ProgramData': 'ProgramData',
  'Users/Public': 'users/Public',
};

/// Resolves the absolute local save root for a game from the bridge's
/// `(knownFolder, relativePath)` tuple (see `CloudSaveConfig.localPath()`).
/// `prefixPath` is the game's Proton prefix directory (the parent of the
/// actual Wine prefix at `<prefixPath>/pfx`), `installPath` the game's
/// install directory (used for the `INSTALLATION_PATH` folder key).
String resolveSaveRoot(
  String knownFolder,
  String relativePath, {
  required String prefixPath,
  required String installPath,
}) {
  final String base;
  if (knownFolder == 'INSTALLATION_PATH') {
    base = installPath;
  } else {
    final folder = _knownFolderPrefixPaths[knownFolder];
    if (folder == null) {
      throw ArgumentError('Unknown save folder key: $knownFolder');
    }
    base = '$prefixPath/pfx/drive_c/$folder';
  }
  return relativePath.isEmpty ? base : '$base/$relativePath';
}

/// Recursively lists every file under [root], returning paths relative to
/// [root] (POSIX-style separators, suitable for use as a save file's
/// `urlPath`). Returns an empty list if [root] doesn't exist.
List<String> listLocalSaveFiles(String root) {
  final dir = Directory(root);
  if (!dir.existsSync()) {
    return [];
  }
  final rootPath = dir.path;
  return dir
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .map((file) {
        var relative = file.path.substring(rootPath.length);
        if (relative.startsWith(Platform.pathSeparator)) {
          relative = relative.substring(1);
        }
        return relative.replaceAll(Platform.pathSeparator, '/');
      })
      .toList();
}
