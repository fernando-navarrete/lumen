import 'package:gogdl_flutter/gogdl_flutter.dart'
    hide GameBuild, DownloadableProduct, ProtonRelease;
import 'package:gogdl_flutter/gogdl_flutter.dart' as bridge
    show GameBuild, DownloadableProduct, ProtonRelease;
import 'package:lumen/common/gog_error.dart';
import 'package:lumen/models/downloadable_product.dart';
import 'package:lumen/models/game_build.dart';
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
    var result = await _api.getGameBuilds(gameId: gameId);
    return result.map(_adaptBuild).toList();
  }

  @override
  Future<List<DownloadableProduct>> getDownloadableProducts({
    required int gameId,
    required String buildName,
  }) async {
    var result = await _api.getDownloadableProducts(
      gameId: gameId,
      buildName: buildName,
    );
    return result.map(_adaptProduct).toList();
  }

  @override
  Stream<DownloadGameProgress> downloadGame({
    required int gameId,
    required String path,
    required String buildName,
    required List<int> selectedProducts,
  }) => guardBridgeStream(
    () => _api.downloadGame(
      gameId: gameId,
      path: path,
      buildName: buildName,
      selectedProducts: selectedProducts,
    ),
  );

  @override
  Stream<VerifyDownloadProgress> verifyDownload({
    required int gameId,
    required String path,
    required String buildName,
    required List<int> selectedProducts,
  }) => guardBridgeStream(
    () => _api.verifyDownload(
      gameId: gameId,
      path: path,
      buildName: buildName,
      selectedProducts: selectedProducts,
    ),
  );

  @override
  Stream<RepairGameProgress> repairDownload({
    required int gameId,
    required String path,
    required String buildName,
    required List<int> selectedProducts,
  }) => guardBridgeStream(
    () => _api.repairGame(
      gameId: gameId,
      path: path,
      buildName: buildName,
      selectedProducts: selectedProducts,
    ),
  );

  @override
  Future<List<ProtonRelease>> getProtonReleases(int page) async {
    try {
      var result = await _api.getProtonReleases(page: page);
      return result.map(_adaptRelease).toList();
    } on GogError catch (e) {
      logGogError(e);
      return [];
    }
  }

  @override
  Stream<ProtonDownloadProgress> downloadProtonRelease({
    required String tagName,
    required String path,
  }) => guardBridgeStream(
    () => _api.downloadProtonRelease(tagName: tagName, path: path),
  );

  @override
  Stream<DownloadSavesProgress> downloadSaves({
    required int gameId,
    required String buildName,
    required String prefix,
    required String installPath,
  }) => guardBridgeStream(
    () => _api.downloadSaveFiles(
      gameId: gameId,
      buildName: buildName,
      prefix: prefix,
      installPath: installPath,
    ),
  );

  @override
  Stream<UploadSavesProgress> uploadSaves({
    required int gameId,
    required String buildName,
    required String prefix,
    required String installPath,
  }) => guardBridgeStream(
    () => _api.uploadSaveFiles(
      gameId: gameId,
      buildName: buildName,
      prefix: prefix,
      installPath: installPath,
    ),
  );

  @override
  void dispose() => _api.dispose();

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
