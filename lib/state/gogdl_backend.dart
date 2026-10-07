import 'dart:async';

import 'package:gogdl_flutter/gogdl_flutter.dart'
    hide GameBuild, DownloadableProduct, ProtonRelease, InstallSize;
import 'package:gogdl_flutter/gogdl_flutter.dart'
    as bridge
    show GameBuild, DownloadableProduct, ProtonRelease, InstallSize;
import 'package:lumen/models/downloadable_product.dart';
import 'package:lumen/models/game_build.dart';
import 'package:lumen/models/install_size.dart';
import 'package:lumen/models/proton_release.dart';
import 'package:lumen/state/bridge_stream.dart';
import 'package:lumen/state/gog_backend.dart';

/// [GogBackend] implementation backed by `gogdl_flutter`, adapting `GogdlApi`
/// calls to the interface [GogState] talks to.
class GogdlBackend implements GogBackend {
  final GogdlApi _api;

  GogdlBackend(this._api);

  @override
  String getLoginUrl() => _api.getLoginLink();

  @override
  Future<String> loginWithCode(String code) => _api.loginWithCode(code: code);

  @override
  Future<void> restoreAuth(String token) => _api.restoreAuth(jsonStr: token);

  @override
  Future<void> setTokenRefreshCallback(Future<void> Function(String) onAuth) =>
      _api.setTokenRefreshCallback(callback: onAuth);

  @override
  Future<void> removeTokenRefreshCallback() =>
      _api.removeTokenRefreshCallback();

  @override
  Future<List<int>> getOwnedGames() => _api.getOwnedGames();

  @override
  Future<String> getGameTitle(int gameId) => _api.getGameTitle(gameId: gameId);

  @override
  Future<String> getBackgroundImageLink(int gameId) =>
      _api.getBackgroundImageLink(gameId: gameId);

  @override
  Future<String> getGameBoxartLink(int gameId) =>
      _api.getGameBoxartLink(gameId: gameId);

  @override
  Future<String> getGameSummary(int gameId) =>
      _api.getGameSummary(gameId: gameId);

  @override
  Future<List<String>> getGameScreenshots(int gameId) =>
      _api.getGameScreenshots(gameId: gameId);

  @override
  Future<List<GameBuild>> getGameBuilds(int gameId) async {
    final result = await _api.getGameBuilds(gameId: gameId);
    return result.map(_adaptBuild).toList();
  }

  @override
  Future<List<DownloadableProduct>> getDownloadableProducts({
    required int gameId,
    required String buildName,
  }) async {
    final result = await _api.getDownloadableProducts(
      gameId: gameId,
      buildName: buildName,
    );
    return result.map(_adaptProduct).toList();
  }

  @override
  Future<InstallSize> getInstallSize({
    required int gameId,
    required String buildName,
    required List<int> selectedProducts,
  }) async {
    final size = await _api.getInstallSize(
      gameId: gameId,
      buildName: buildName,
      selectedProducts: selectedProducts,
    );
    return _adaptInstallSize(size);
  }

  @override
  Future<int> getFreeSpace(String path) async =>
      (await _api.getFreeSpace(path: path)).toInt();

  @override
  Stream<DownloadGameProgress> downloadGame({
    required int gameId,
    required String path,
    required String buildName,
    required List<int> selectedProducts,
    required JobCancel cancel,
  }) => _job(
    cancel,
    (token) => _api.downloadGame(
      gameId: gameId,
      path: path,
      buildName: buildName,
      selectedProducts: selectedProducts,
      cancel: token,
    ),
  );

  @override
  Stream<VerifyDownloadProgress> verifyDownload({
    required int gameId,
    required String path,
    required String buildName,
    required List<int> selectedProducts,
    required JobCancel cancel,
  }) => _job(
    cancel,
    (token) => _api.verifyDownload(
      gameId: gameId,
      path: path,
      buildName: buildName,
      selectedProducts: selectedProducts,
      cancel: token,
    ),
  );

  @override
  Stream<RepairGameProgress> repairDownload({
    required int gameId,
    required String path,
    required String buildName,
    required List<int> selectedProducts,
    required JobCancel cancel,
  }) => _job(
    cancel,
    (token) => _api.repairGame(
      gameId: gameId,
      path: path,
      buildName: buildName,
      selectedProducts: selectedProducts,
      cancel: token,
    ),
  );

  @override
  Future<List<ProtonRelease>> getProtonReleases(int page) async {
    final result = await _api.getProtonReleases(page: page);
    return result.map(_adaptRelease).toList();
  }

  @override
  Stream<ProtonDownloadProgress> downloadProtonRelease({
    required String tagName,
    required String path,
    required JobCancel cancel,
  }) => _job(
    cancel,
    (token) =>
        _api.downloadProtonRelease(tagName: tagName, path: path, cancel: token),
  );

  @override
  Stream<DownloadSavesProgress> downloadSaves({
    required int gameId,
    required String buildName,
    required String prefix,
    required String installPath,
    required JobCancel cancel,
  }) => _job(
    cancel,
    (token) => _api.downloadSaveFiles(
      gameId: gameId,
      buildName: buildName,
      prefix: prefix,
      installPath: installPath,
      cancel: token,
    ),
  );

  @override
  Stream<UploadSavesProgress> uploadSaves({
    required int gameId,
    required String buildName,
    required String prefix,
    required String installPath,
    required JobCancel cancel,
  }) => _job(
    cancel,
    (token) => _api.uploadSaveFiles(
      gameId: gameId,
      buildName: buildName,
      prefix: prefix,
      installPath: installPath,
      cancel: token,
    ),
  );

  @override
  void dispose() => _api.dispose();

  /// Starts a bridge job with a fresh [CancelToken] wired to [cancel]. The
  /// token is made when the stream is first listened to, and a [cancel]
  /// that's already fired (even before that) cancels it straight away — the
  /// bridge then ends the job with `Cancelled` before doing any work.
  Stream<T> _job<T>(
    JobCancel cancel,
    Stream<T> Function(CancelToken token) start,
  ) => guardBridgeStream(() {
    final token = CancelToken();
    unawaited(cancel.whenCancelled.then((_) => token.cancel()));
    return start(token);
  });

  InstallSize _adaptInstallSize(bridge.InstallSize s) => InstallSize(
    downloadBytes: s.downloadBytes.toInt(),
    diskBytes: s.diskBytes.toInt(),
  );

  GameBuild _adaptBuild(bridge.GameBuild b) => GameBuild(
    buildId: b.buildId,
    versionName: b.versionName,
    releaseDate: b.releaseDate,
    releaseDateTimestamp: b.releaseDateTimestamp,
  );

  DownloadableProduct _adaptProduct(bridge.DownloadableProduct p) =>
      DownloadableProduct(id: p.id, name: p.name, productType: p.productType);

  ProtonRelease _adaptRelease(bridge.ProtonRelease r) =>
      ProtonRelease(tagName: r.tagName, downloadSize: r.downloadSize.toInt());
}
