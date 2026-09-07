import 'package:gogdl_flutter/gogdl_flutter.dart';
import 'package:lumen/models/cloud_save.dart';
import 'package:lumen/models/progress.dart';

/// Thrown by [GogBackend] methods that have no working implementation —
/// currently everything, since `gogdl_flutter` is being rebuilt from
/// scratch. See [UnimplementedBackend] in `unimplemented_backend.dart`.
class GogUnavailable implements Exception {
  final String message;

  const GogUnavailable(this.message);

  @override
  String toString() => 'GogUnavailable: $message';
}

/// Everything [GogState] needs from a GOG backend, abstracted away from any
/// particular implementation. This is the seam `gogdl_flutter` used to fill
/// directly — [GogState] talks only to this interface, so re-wiring a
/// rebuilt bridge later is a single `GogBackend` implementation plus
/// swapping the constructor argument in `gogStateProvider`, with no changes
/// anywhere else in the app.
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
  Future<void> setTokenRefreshCallback(Future<void> Function(String auth) onAuth);

  /// Unregisters the callback set by [setTokenRefreshCallback], if any.
  Future<void> removeTokenRefreshCallback();

  Future<void> configureDownload({
    required int minConcurrency,
    required int maxConcurrency,
    required int idleTimeout,
  });

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
  Stream<DownloadProgress> downloadGame({
    required int gameId,
    required String path,
    required String buildName,
    required List<String> selectedProducts,
  });
  Stream<VerificationProgress> verifyDownload({
    required int gameId,
    required String path,
    required String buildName,
    required List<String> selectedProducts,
  });
  Stream<RepairProgress> repairDownload({
    required int gameId,
    required String path,
    required String buildName,
    required List<String> selectedProducts,
  });

  // Proton-GE
  Future<List<ProtonRelease>> getProtonReleases(int page);
  Stream<ProtonDownloadProgress> downloadProtonRelease({
    required String tagName,
    required String path,
  });

  // Cloud saves
  Future<SaveAuthIds> getSaveAuthIds(int gameId);
  Future<CloudSaveConfig> getSaveRemoteConfig(String clientId);
  Future<List<CloudSaveFile>> getSaveFileList({
    required String clientId,
    required String clientSecret,
  });
  Stream<SaveTransferProgress> downloadSave({
    required CloudSaveFile saveFile,
    required String clientId,
    required String clientSecret,
    required String path,
  });
  Stream<SaveTransferProgress> uploadSave({
    required String clientId,
    required String clientSecret,
    required String path,
    required String urlPath,
  });

  void dispose();
}
