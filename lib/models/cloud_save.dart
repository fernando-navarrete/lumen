// Cloud-save types, app-owned replacements for the bridge's
// `SaveAuthIds`/`CloudSaveConfig`/`CloudSaveFile` — see
// `lib/state/gog_backend.dart`.

/// Per-game credentials for the GOG cloud-save API.
class SaveAuthIds {
  final String clientId;
  final String clientSecret;

  const SaveAuthIds({required this.clientId, required this.clientSecret});
}

/// A game's cloud-save support and where its local save files live.
///
/// The bridge exposed the local path as `localPath() -> (String, String)`
/// (a `(knownFolder, relativePath)` record); this splits that into two
/// fields that callers destructure the same way at the call site — see
/// `lib/state/saves_state.dart` and
/// `lib/screens/home/pages/library/saves_tab.dart`.
class CloudSaveConfig {
  final bool isSupported;
  final String knownFolder;
  final String relativePath;

  const CloudSaveConfig({
    required this.isSupported,
    required this.knownFolder,
    required this.relativePath,
  });
}

/// A single file present in a game's cloud save storage.
class CloudSaveFile {
  final String path;

  const CloudSaveFile({required this.path});
}
