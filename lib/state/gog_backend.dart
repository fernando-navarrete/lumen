import 'package:gogdl_flutter/gogdl_flutter.dart';

/// Everything [GogState] needs from a GOG backend, abstracted away from any
/// particular implementation. [GogState] talks only to this interface —
/// [GogdlBackend] (`gogdl_backend.dart`) is the implementation actually wired
/// up in `gogStateProvider`, and the seam lets a fake implementation stand in
/// for it in tests.
///
/// Long-running operations are exposed as `Stream<T>`, matching the
/// convention the bridge established — never `Future`.
abstract class GogBackend {
  // Auth
  String getLoginUrl();
  Future<String> loginWithCode(String code);
  Future<void> restoreAuth(String token);

  /// Registers [onAuth] to be called with serialized auth JSON — the same
  /// shape [restoreAuth] accepts — whenever the backend refreshes the access
  /// token internally. This is the only notification that the refresh token
  /// rotated; without persisting each call's payload, a stored token from
  /// [loginWithCode]/[restoreAuth] can go stale after the first refresh.
  Future<void> setTokenRefreshCallback(
    Future<void> Function(String auth) onAuth,
  );

  /// Unregisters the callback set by [setTokenRefreshCallback], if any.
  Future<void> removeTokenRefreshCallback();

  // Metadata
  Future<List<int>> getOwnedGames();
  Future<String> getGameTitle(int gameId);
  Future<String> getBackgroundImageLink(int gameId);
  Future<String> getGameBoxartLink(int gameId);
  Future<String> getGameSummary(int gameId);
  Future<List<String>> getGameScreenshots(int gameId);
  Future<List<GameBuild>> getGameBuilds(int gameId);
  Future<List<DownloadableProduct>> getDownloadableProducts({
    required int gameId,
    required String buildName,
  });

  // Downloads / verify / repair
  /// Bridge-owned freezed union, like [downloadProtonRelease]'s
  /// `ProtonDownloadProgress` — not an app-owned model. [DownloadsNotifier]
  /// adapts it directly.
  Stream<DownloadGameProgress> downloadGame({
    required int gameId,
    required String path,
    required String buildName,
    required List<int> selectedProducts,
  });
  /// Bridge-owned freezed union, like [downloadProtonRelease]'s
  /// `ProtonDownloadProgress` — not an app-owned model. [DownloadsNotifier]
  /// adapts it directly.
  Stream<VerifyDownloadProgress> verifyDownload({
    required int gameId,
    required String path,
    required String buildName,
    required List<int> selectedProducts,
  });
  /// Bridge-owned freezed union, like [downloadProtonRelease]'s
  /// `ProtonDownloadProgress` — not an app-owned model. [DownloadsNotifier]
  /// adapts it directly.
  Stream<RepairGameProgress> repairDownload({
    required int gameId,
    required String path,
    required String buildName,
    required List<int> selectedProducts,
  });

  // Proton-GE
  Future<List<ProtonRelease>> getProtonReleases(int page);
  Stream<ProtonDownloadProgress> downloadProtonRelease({
    required String tagName,
    required String path,
  });

  // Cloud saves
  /// Downloads every cloud save file of [gameId] into the game's local save
  /// locations, which the backend resolves itself. [prefix] is the Wine
  /// prefix that contains `drive_c` (i.e. `<protonPrefixPath>/pfx`, not the
  /// Proton prefix root); [installPath] backs `INSTALL`-relative locations.
  /// Bridge-owned freezed union, like [downloadProtonRelease]'s
  /// `ProtonDownloadProgress` — not an app-owned model. [SavesNotifier]
  /// adapts it directly.
  Stream<DownloadSavesProgress> downloadSaves({
    required int gameId,
    required String buildName,
    required String prefix,
    required String installPath,
  });

  /// Uploads every local save file of [gameId] to the cloud. [prefix] and
  /// [installPath] mean the same as for [downloadSaves]. Bridge-owned
  /// freezed union, adapted directly by [SavesNotifier].
  Stream<UploadSavesProgress> uploadSaves({
    required int gameId,
    required String buildName,
    required String prefix,
    required String installPath,
  });

  void dispose();
}
