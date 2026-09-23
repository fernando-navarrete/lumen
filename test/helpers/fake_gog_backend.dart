import 'dart:async';

import 'package:gogdl_flutter/gogdl_flutter.dart'
    hide GameBuild, DownloadableProduct, ProtonRelease;
import 'package:lumen/models/downloadable_product.dart';
import 'package:lumen/models/game_build.dart';
import 'package:lumen/models/proton_release.dart';
import 'package:lumen/state/gog_backend.dart';

/// A single recorded call to [FakeGogBackend], for assertions like "repair
/// was started with build X".
class FakeCall {
  final String method;
  final Map<String, Object?> args;

  FakeCall(this.method, this.args);

  @override
  String toString() => '$method($args)';
}

/// In-memory [GogBackend] for tests. Never touches `GogdlApi`/`RustLib`, so
/// tests using it need no native library loaded (see Phase 0 of
/// `devlog/v1.1.0-foundation.md`).
///
/// - Canned return values for the metadata getters are public fields, settable
///   per test.
/// - [throwOn] makes a named method throw the given error instead of
///   returning/emitting normally.
/// - [calls] logs every invocation (method + args) in order.
/// - Every stream method (download/verify/repair/saves/Proton download)
///   creates a **fresh** controller each call and keeps it as "the latest"
///   for that key, mirroring the bridge (a finished stream can't be
///   re-listened to) and letting a re-run get a new one. Tests drive it with
///   the matching `*Controller` accessor, then `add`/`addError`/`close`.
class FakeGogBackend implements GogBackend {
  // ---- Canned metadata ----
  String loginUrl = '';
  String loginResult = '';
  bool disposed = false;

  List<int> ownedGames = [];
  final Map<int, String> titles = {};
  final Map<int, String> backgroundLinks = {};
  final Map<int, String> boxartLinks = {};
  final Map<int, String> summaries = {};
  final Map<int, List<String>> screenshots = {};
  final Map<int, List<GameBuild>> builds = {};
  final Map<int, List<DownloadableProduct>> products = {};
  List<ProtonRelease> protonReleases = [];

  /// Set by [setTokenRefreshCallback]; call it in a test to simulate the
  /// bridge refreshing the token. Cleared by [removeTokenRefreshCallback].
  Future<void> Function(String auth)? onTokenRefresh;

  // ---- Failure injection ----
  /// Keyed by method name (e.g. `'getOwnedGames'`); the error to throw
  /// instead of returning/emitting normally.
  final Map<String, Object> throwOn = {};

  // ---- Call log ----
  final List<FakeCall> calls = [];

  List<FakeCall> callsTo(String method) =>
      calls.where((c) => c.method == method).toList();

  void _record(String method, [Map<String, Object?> args = const {}]) {
    calls.add(FakeCall(method, args));
  }

  void _maybeThrow(String method) {
    final error = throwOn[method];
    if (error != null) {
      throw error;
    }
  }

  // ---- Streams ----
  final Map<int, StreamController<DownloadGameProgress>> _downloadControllers =
      {};
  final Map<int, StreamController<VerifyDownloadProgress>>
  _verifyControllers = {};
  final Map<int, StreamController<RepairGameProgress>> _repairControllers =
      {};
  final Map<int, StreamController<DownloadSavesProgress>>
  _saveDownloadControllers = {};
  final Map<int, StreamController<UploadSavesProgress>>
  _saveUploadControllers = {};
  final Map<String, StreamController<ProtonDownloadProgress>>
  _protonDownloadControllers = {};

  StreamController<DownloadGameProgress> downloadController(int gameId) =>
      _downloadControllers[gameId]!;
  StreamController<VerifyDownloadProgress> verifyController(int gameId) =>
      _verifyControllers[gameId]!;
  StreamController<RepairGameProgress> repairController(int gameId) =>
      _repairControllers[gameId]!;
  StreamController<DownloadSavesProgress> saveDownloadController(
    int gameId,
  ) => _saveDownloadControllers[gameId]!;
  StreamController<UploadSavesProgress> saveUploadController(int gameId) =>
      _saveUploadControllers[gameId]!;
  StreamController<ProtonDownloadProgress> protonDownloadController(
    String tagName,
  ) => _protonDownloadControllers[tagName]!;

  /// Closes every controller ever created, for teardown.
  Future<void> closeAll() async {
    for (final c in _downloadControllers.values) {
      await c.close();
    }
    for (final c in _verifyControllers.values) {
      await c.close();
    }
    for (final c in _repairControllers.values) {
      await c.close();
    }
    for (final c in _saveDownloadControllers.values) {
      await c.close();
    }
    for (final c in _saveUploadControllers.values) {
      await c.close();
    }
    for (final c in _protonDownloadControllers.values) {
      await c.close();
    }
  }

  // ---- Auth ----
  @override
  String getLoginUrl() {
    _record('getLoginUrl');
    _maybeThrow('getLoginUrl');
    return loginUrl;
  }

  @override
  Future<String> loginWithCode(String code) async {
    _record('loginWithCode', {'code': code});
    _maybeThrow('loginWithCode');
    return loginResult;
  }

  @override
  Future<void> restoreAuth(String token) async {
    _record('restoreAuth', {'token': token});
    _maybeThrow('restoreAuth');
  }

  @override
  Future<void> setTokenRefreshCallback(
    Future<void> Function(String auth) onAuth,
  ) async {
    _record('setTokenRefreshCallback');
    _maybeThrow('setTokenRefreshCallback');
    onTokenRefresh = onAuth;
  }

  @override
  Future<void> removeTokenRefreshCallback() async {
    _record('removeTokenRefreshCallback');
    _maybeThrow('removeTokenRefreshCallback');
    onTokenRefresh = null;
  }

  // ---- Metadata ----
  @override
  Future<List<int>> getOwnedGames() async {
    _record('getOwnedGames');
    _maybeThrow('getOwnedGames');
    return ownedGames;
  }

  @override
  Future<String> getGameTitle(int gameId) async {
    _record('getGameTitle', {'gameId': gameId});
    _maybeThrow('getGameTitle');
    return titles[gameId] ?? '';
  }

  @override
  Future<String> getBackgroundImageLink(int gameId) async {
    _record('getBackgroundImageLink', {'gameId': gameId});
    _maybeThrow('getBackgroundImageLink');
    return backgroundLinks[gameId] ?? '';
  }

  @override
  Future<String> getGameBoxartLink(int gameId) async {
    _record('getGameBoxartLink', {'gameId': gameId});
    _maybeThrow('getGameBoxartLink');
    return boxartLinks[gameId] ?? '';
  }

  @override
  Future<String> getGameSummary(int gameId) async {
    _record('getGameSummary', {'gameId': gameId});
    _maybeThrow('getGameSummary');
    return summaries[gameId] ?? '';
  }

  @override
  Future<List<String>> getGameScreenshots(int gameId) async {
    _record('getGameScreenshots', {'gameId': gameId});
    _maybeThrow('getGameScreenshots');
    return screenshots[gameId] ?? [];
  }

  @override
  Future<List<GameBuild>> getGameBuilds(int gameId) async {
    _record('getGameBuilds', {'gameId': gameId});
    _maybeThrow('getGameBuilds');
    return builds[gameId] ?? [];
  }

  @override
  Future<List<DownloadableProduct>> getDownloadableProducts({
    required int gameId,
    required String buildName,
  }) async {
    _record('getDownloadableProducts', {
      'gameId': gameId,
      'buildName': buildName,
    });
    _maybeThrow('getDownloadableProducts');
    return products[gameId] ?? [];
  }

  // ---- Downloads / verify / repair ----
  @override
  Stream<DownloadGameProgress> downloadGame({
    required int gameId,
    required String path,
    required String buildName,
    required List<int> selectedProducts,
  }) {
    _record('downloadGame', {
      'gameId': gameId,
      'path': path,
      'buildName': buildName,
      'selectedProducts': selectedProducts,
    });
    _maybeThrow('downloadGame');
    final controller = StreamController<DownloadGameProgress>();
    _downloadControllers[gameId] = controller;
    return controller.stream;
  }

  @override
  Stream<VerifyDownloadProgress> verifyDownload({
    required int gameId,
    required String path,
    required String buildName,
    required List<int> selectedProducts,
  }) {
    _record('verifyDownload', {
      'gameId': gameId,
      'path': path,
      'buildName': buildName,
      'selectedProducts': selectedProducts,
    });
    _maybeThrow('verifyDownload');
    final controller = StreamController<VerifyDownloadProgress>();
    _verifyControllers[gameId] = controller;
    return controller.stream;
  }

  @override
  Stream<RepairGameProgress> repairDownload({
    required int gameId,
    required String path,
    required String buildName,
    required List<int> selectedProducts,
  }) {
    _record('repairDownload', {
      'gameId': gameId,
      'path': path,
      'buildName': buildName,
      'selectedProducts': selectedProducts,
    });
    _maybeThrow('repairDownload');
    final controller = StreamController<RepairGameProgress>();
    _repairControllers[gameId] = controller;
    return controller.stream;
  }

  // ---- Proton-GE ----
  @override
  Future<List<ProtonRelease>> getProtonReleases(int page) async {
    _record('getProtonReleases', {'page': page});
    _maybeThrow('getProtonReleases');
    return protonReleases;
  }

  @override
  Stream<ProtonDownloadProgress> downloadProtonRelease({
    required String tagName,
    required String path,
  }) {
    _record('downloadProtonRelease', {'tagName': tagName, 'path': path});
    _maybeThrow('downloadProtonRelease');
    final controller = StreamController<ProtonDownloadProgress>();
    _protonDownloadControllers[tagName] = controller;
    return controller.stream;
  }

  // ---- Cloud saves ----
  @override
  Stream<DownloadSavesProgress> downloadSaves({
    required int gameId,
    required String buildName,
    required String prefix,
    required String installPath,
  }) {
    _record('downloadSaves', {
      'gameId': gameId,
      'buildName': buildName,
      'prefix': prefix,
      'installPath': installPath,
    });
    _maybeThrow('downloadSaves');
    final controller = StreamController<DownloadSavesProgress>();
    _saveDownloadControllers[gameId] = controller;
    return controller.stream;
  }

  @override
  Stream<UploadSavesProgress> uploadSaves({
    required int gameId,
    required String buildName,
    required String prefix,
    required String installPath,
  }) {
    _record('uploadSaves', {
      'gameId': gameId,
      'buildName': buildName,
      'prefix': prefix,
      'installPath': installPath,
    });
    _maybeThrow('uploadSaves');
    final controller = StreamController<UploadSavesProgress>();
    _saveUploadControllers[gameId] = controller;
    return controller.stream;
  }

  @override
  void dispose() {
    _record('dispose');
    disposed = true;
  }
}
