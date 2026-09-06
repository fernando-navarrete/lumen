import 'package:gogdl_flutter/gogdl_flutter.dart';
import 'package:lumen/models/cloud_save.dart';
import 'package:lumen/models/downloadable_product.dart';
import 'package:lumen/models/game_build.dart';
import 'package:lumen/models/progress.dart';
import 'package:lumen/models/proton_release.dart';
import 'package:lumen/state/gog_backend.dart';
import 'package:lumen/state/unimplemented_backend.dart';

/// [GogBackend] backed by the rebuilt `gogdl_flutter`.
///
/// The new bridge is being rebuilt one feature at a time (see
/// lumen-project's workspace `CLAUDE.md`, "The restart line"), so this class
/// implements only what `GogdlApi` actually exposes today and delegates
/// everything else to [UnimplementedBackend]. As each capability lands on
/// the Rust side, replace its delegated line here with a real call — no
/// other file in the app needs to change.
class RealGogBackend implements GogBackend {
  final GogdlApi _api;
  final GogBackend _stub = UnimplementedBackend();

  RealGogBackend(this._api);

  @override
  String getLoginUrl() => _api.getLoginLink();

  @override
  Future<String> loginWithCode(String code) => _stub.loginWithCode(code);

  @override
  Future<void> restoreAuth(String token) => _stub.restoreAuth(token);

  @override
  Future<void> refreshAuth({required Future<void> Function(String) onAuth}) =>
      _stub.refreshAuth(onAuth: onAuth);

  @override
  Future<void> configureDownload({
    required int minConcurrency,
    required int maxConcurrency,
    required int idleTimeout,
  }) => _stub.configureDownload(
    minConcurrency: minConcurrency,
    maxConcurrency: maxConcurrency,
    idleTimeout: idleTimeout,
  );

  @override
  Future<List<int>> getOwnedGames() => _api.getOwnedGames();

  @override
  Future<String> getGameTitle(int gameId) => _stub.getGameTitle(gameId);

  @override
  Future<String> getBackgroundImageLink(int gameId) =>
      _stub.getBackgroundImageLink(gameId);

  @override
  Future<String> getGameBoxartLink(int gameId) =>
      _stub.getGameBoxartLink(gameId);

  @override
  Future<String> getGameSummary(int gameId) => _stub.getGameSummary(gameId);

  @override
  Future<List<String>> getGameScreenshots(int gameId) =>
      _stub.getGameScreenshots(gameId);

  @override
  Future<List<GameBuild>> getGameBuilds(int gameId) =>
      _stub.getGameBuilds(gameId);

  @override
  Future<List<DownloadableProduct>> getDownloadableProducts({
    required int gameId,
    required String buildName,
  }) => _stub.getDownloadableProducts(gameId: gameId, buildName: buildName);

  @override
  Stream<DownloadProgress> downloadGame({
    required int gameId,
    required String path,
    required String buildName,
    required List<String> selectedProducts,
  }) => _stub.downloadGame(
    gameId: gameId,
    path: path,
    buildName: buildName,
    selectedProducts: selectedProducts,
  );

  @override
  Stream<VerificationProgress> verifyDownload({
    required int gameId,
    required String path,
    required String buildName,
    required List<String> selectedProducts,
  }) => _stub.verifyDownload(
    gameId: gameId,
    path: path,
    buildName: buildName,
    selectedProducts: selectedProducts,
  );

  @override
  Stream<RepairProgress> repairDownload({
    required int gameId,
    required String path,
    required String buildName,
    required List<String> selectedProducts,
  }) => _stub.repairDownload(
    gameId: gameId,
    path: path,
    buildName: buildName,
    selectedProducts: selectedProducts,
  );

  @override
  Future<List<ProtonRelease>> getProtonReleases(int page) =>
      _stub.getProtonReleases(page);

  @override
  Stream<ProtonDownloadProgress> downloadProtonRelease({
    required ProtonRelease release,
    required String path,
  }) => _stub.downloadProtonRelease(release: release, path: path);

  @override
  Future<SaveAuthIds> getSaveAuthIds(int gameId) =>
      _stub.getSaveAuthIds(gameId);

  @override
  Future<CloudSaveConfig> getSaveRemoteConfig(String clientId) =>
      _stub.getSaveRemoteConfig(clientId);

  @override
  Future<List<CloudSaveFile>> getSaveFileList({
    required String clientId,
    required String clientSecret,
  }) => _stub.getSaveFileList(clientId: clientId, clientSecret: clientSecret);

  @override
  Stream<SaveTransferProgress> downloadSave({
    required CloudSaveFile saveFile,
    required String clientId,
    required String clientSecret,
    required String path,
  }) => _stub.downloadSave(
    saveFile: saveFile,
    clientId: clientId,
    clientSecret: clientSecret,
    path: path,
  );

  @override
  Stream<SaveTransferProgress> uploadSave({
    required String clientId,
    required String clientSecret,
    required String path,
    required String urlPath,
  }) => _stub.uploadSave(
    clientId: clientId,
    clientSecret: clientSecret,
    path: path,
    urlPath: urlPath,
  );

  @override
  void dispose() => _api.dispose();
}
