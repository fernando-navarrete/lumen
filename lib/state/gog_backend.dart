import 'dart:async';

import 'package:gogdl_flutter/gogdl_flutter.dart'
    hide GameBuild, DownloadableProduct, ProtonRelease, InstallSize;
import 'package:lumen/models/downloadable_product.dart';
import 'package:lumen/models/game_build.dart';
import 'package:lumen/models/install_size.dart';
import 'package:lumen/models/proton_release.dart';

/// Everything [GogState] needs from a GOG backend, abstracted away from any
/// particular implementation. [GogState] talks only to this interface —
/// [GogdlBackend] (`gogdl_backend.dart`) is the implementation actually wired
/// up in `gogBackendProvider` (`gog_state.dart`), which `gogStateProvider`
/// watches — the seam lets a fake implementation stand in for it in tests.
///
/// Long-running operations are exposed as `Stream<T>`, matching the
/// convention the bridge established — never `Future`.
///
/// Every job stream takes a [JobCancel], the app-owned cancel handle. The
/// bridge's own cancel token never appears here, so tests never construct a
/// native object: [GogdlBackend] creates one per job and forwards
/// [JobCancel.cancel] to it. A cancelled job ends its stream with its
/// `*_Cancelled` event and no error.
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

  /// The download and on-disk size of [selectedProducts] of [buildName].
  Future<InstallSize> getInstallSize({
    required int gameId,
    required String buildName,
    required List<int> selectedProducts,
  });

  /// Free bytes on the disk [path] is on — the figure the download's own
  /// pre-flight check uses. [path] needn't exist.
  Future<int> getFreeSpace(String path);

  // Downloads / verify / repair
  /// Bridge-owned freezed union, like [downloadProtonRelease]'s
  /// `ProtonDownloadProgress` — not an app-owned model. [DownloadsNotifier]
  /// adapts it directly.
  Stream<DownloadGameProgress> downloadGame({
    required int gameId,
    required String path,
    required String buildName,
    required List<int> selectedProducts,
    required JobCancel cancel,
  });

  /// Bridge-owned freezed union, like [downloadProtonRelease]'s
  /// `ProtonDownloadProgress` — not an app-owned model. [DownloadsNotifier]
  /// adapts it directly.
  Stream<VerifyDownloadProgress> verifyDownload({
    required int gameId,
    required String path,
    required String buildName,
    required List<int> selectedProducts,
    required JobCancel cancel,
  });

  /// Bridge-owned freezed union, like [downloadProtonRelease]'s
  /// `ProtonDownloadProgress` — not an app-owned model. [DownloadsNotifier]
  /// adapts it directly.
  Stream<RepairGameProgress> repairDownload({
    required int gameId,
    required String path,
    required String buildName,
    required List<int> selectedProducts,
    required JobCancel cancel,
  });

  // Proton-GE
  Future<List<ProtonRelease>> getProtonReleases(int page);
  Stream<ProtonDownloadProgress> downloadProtonRelease({
    required String tagName,
    required String path,
    required JobCancel cancel,
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
    required JobCancel cancel,
  });

  /// Uploads every local save file of [gameId] to the cloud. [prefix] and
  /// [installPath] mean the same as for [downloadSaves]. Bridge-owned
  /// freezed union, adapted directly by [SavesNotifier].
  Stream<UploadSavesProgress> uploadSaves({
    required int gameId,
    required String buildName,
    required String prefix,
    required String installPath,
    required JobCancel cancel,
  });

  void dispose();
}

/// Cancels one backend job. Plain Dart, so tests can hold one without the
/// native bridge. Idempotent; a job started with an already-cancelled handle
/// is cancelled before it does anything.
class JobCancel {
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  /// Completes when [cancel] is first called.
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) {
      _cancelled.complete();
    }
  }
}
