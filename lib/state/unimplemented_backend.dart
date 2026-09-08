import 'package:gogdl_flutter/gogdl_flutter.dart';
import 'package:lumen/models/cloud_save.dart';
import 'package:lumen/models/progress.dart';
import 'package:lumen/state/gog_backend.dart';

/// Placeholder [GogBackend] for while `gogdl_flutter` is being rebuilt from
/// scratch (see the lumen-project `restart` line). Every data and stream
/// method throws/emits [GogUnavailable] — [GogState]'s existing
/// try/catch-to-null convention means the whole UI above it already
/// tolerates that as a valid app state.
///
/// The auth/config methods are the deliberate exception: they no-op
/// successfully (and [getLoginUrl] returns `''`) instead of throwing, so
/// [LoginScreen]'s startup flow falls through to [HomeScreen] instead of
/// getting stuck — without this, none of the UI kept during the bridge
/// removal would ever become reachable at runtime.
class UnimplementedBackend implements GogBackend {
  GogUnavailable _unavailable(String method) => GogUnavailable(
    '$method is not implemented — gogdl_flutter has not been rebuilt yet',
  );

  @override
  String getLoginUrl() => '';

  @override
  Future<String> loginWithCode(String code) async =>
      throw _unavailable('loginWithCode');

  @override
  Future<void> restoreAuth(String token) async {
    throw _unavailable('restoreAuth');
  }

  @override
  Future<void> setTokenRefreshCallback(
    Future<void> Function(String auth) onAuth,
  ) async {}

  @override
  Future<void> removeTokenRefreshCallback() async {}

  @override
  Future<void> configureDownload({
    required int minConcurrency,
    required int maxConcurrency,
    required int idleTimeout,
  }) async {}

  @override
  Future<List<int>> getOwnedGames() async =>
      throw _unavailable('getOwnedGames');

  @override
  Future<String> getGameTitle(int gameId) async =>
      throw _unavailable('getGameTitle');

  @override
  Future<String> getBackgroundImageLink(int gameId) async =>
      throw _unavailable('getBackgroundImageLink');

  @override
  Future<String> getGameBoxartLink(int gameId) async =>
      throw _unavailable('getGameBoxartLink');

  @override
  Future<String> getGameSummary(int gameId) async =>
      throw _unavailable('getGameSummary');

  @override
  Future<List<String>> getGameScreenshots(int gameId) async =>
      throw _unavailable('getGameScreenshots');

  @override
  Future<List<GameBuild>> getGameBuilds(int gameId) async =>
      throw _unavailable('getGameBuilds');

  @override
  Future<List<DownloadableProduct>> getDownloadableProducts({
    required int gameId,
    required String buildName,
  }) async => throw _unavailable('getDownloadableProducts');

  @override
  Stream<DownloadGameProgress> downloadGame({
    required int gameId,
    required String path,
    required String buildName,
    required List<int> selectedProducts,
  }) => Stream.error(_unavailable('downloadGame'));

  @override
  Stream<VerifyDownloadProgress> verifyDownload({
    required int gameId,
    required String path,
    required String buildName,
    required List<int> selectedProducts,
  }) => Stream.error(_unavailable('verifyDownload'));

  @override
  Stream<RepairGameProgress> repairDownload({
    required int gameId,
    required String path,
    required String buildName,
    required List<int> selectedProducts,
  }) => Stream.error(_unavailable('repairDownload'));

  @override
  Future<List<ProtonRelease>> getProtonReleases(int page) async =>
      throw _unavailable('getProtonReleases');

  @override
  Stream<ProtonDownloadProgress> downloadProtonRelease({
    required String tagName,
    required String path,
  }) => Stream.error(_unavailable('downloadProtonRelease'));

  @override
  Future<SaveAuthIds> getSaveAuthIds(int gameId) async =>
      throw _unavailable('getSaveAuthIds');

  @override
  Future<CloudSaveConfig> getSaveRemoteConfig(String clientId) async =>
      throw _unavailable('getSaveRemoteConfig');

  @override
  Future<List<CloudSaveFile>> getSaveFileList({
    required String clientId,
    required String clientSecret,
  }) async => throw _unavailable('getSaveFileList');

  @override
  Stream<SaveTransferProgress> downloadSave({
    required CloudSaveFile saveFile,
    required String clientId,
    required String clientSecret,
    required String path,
  }) => Stream.error(_unavailable('downloadSave'));

  @override
  Stream<SaveTransferProgress> uploadSave({
    required String clientId,
    required String clientSecret,
    required String path,
    required String urlPath,
  }) => Stream.error(_unavailable('uploadSave'));

  @override
  void dispose() {}
}
