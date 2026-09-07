import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gogdl_flutter/gogdl_flutter.dart';
import 'package:lumen/models/cloud_save.dart';
import 'package:lumen/models/progress.dart';
import 'package:lumen/models/proton_release.dart';
import 'package:lumen/state/gog_backend.dart';
import 'package:lumen/state/real_gog_backend.dart';

class GogState {
  final GogBackend _backend;
  final HashMap<int, Stream<VerificationProgress>> _verificationStreams =
      HashMap();
  final HashMap<int, Stream<RepairProgress>> _repairStreams = HashMap();
  final HashMap<int, Stream<DownloadProgress>> _downloadStreams = HashMap();
  final HashMap<String, Stream<ProtonDownloadProgress>> _protonDownloadStreams =
      HashMap();

  /// Names and boxart links are static for a session, but callers (e.g. the
  /// Downloads page task cards) call these getters on every rebuild —
  /// several times a second while a download is in flight. Caching the
  /// Future itself (not just its resolved value) means a FutureBuilder fed
  /// the same Future instance across rebuilds stays in its "has data" state
  /// instead of resetting to pending and re-issuing the bridge call.
  final HashMap<int, Future<String?>> _gameNameCache = HashMap();
  final HashMap<int, Future<String>> _boxartLinkCache = HashMap();

  GogState(this._backend);

  String getLoginUrl() {
    try {
      return _backend.getLoginUrl();
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return '';
    }
  }

  Future<void> configureDownload({
    required int minConcurrency,
    required int maxConcurrency,
    required int timeout,
  }) async {
    try {
      await _backend.configureDownload(
        minConcurrency: minConcurrency,
        maxConcurrency: maxConcurrency,
        idleTimeout: timeout,
      );
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      rethrow;
    }
  }

  Future<void> refreshAuthWithCallback() async {
    try {
      await _backend.refreshAuth(
        onAuth: (auth) async {
          final storage = FlutterSecureStorage();
          await storage.write(key: 'auth', value: auth);
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      rethrow;
    }
  }

  Future<String> getGameBackgroundLink(int gameId) async {
    try {
      String link = await _backend.getBackgroundImageLink(gameId);
      return link;
    } catch (e) {
      if (kDebugMode) {
        print(e);
        throw Exception(e);
      }
      return '';
    }
  }

  Future<String> getGameBoxartLink(int gameId) =>
      _boxartLinkCache.putIfAbsent(gameId, () => _fetchGameBoxartLink(gameId));

  Future<String> _fetchGameBoxartLink(int gameId) async {
    try {
      String link = await _backend.getGameBoxartLink(gameId);
      return link;
    } catch (e) {
      if (kDebugMode) {
        print(e);
        throw Exception(e);
      }
      return '';
    }
  }

  Future<String> getGameSummary(int gameId) async {
    try {
      String summary = await _backend.getGameSummary(gameId);
      return summary;
    } catch (e) {
      if (kDebugMode) {
        print(e);
        throw Exception(e);
      }
      return '';
    }
  }

  Future<List<String>> getGameScreenshots(int gameId) async {
    try {
      List<String> screenshots = await _backend.getGameScreenshots(gameId);
      return screenshots;
    } catch (e) {
      if (kDebugMode) {
        print(e);
        throw Exception(e);
      }
      return [];
    }
  }

  Future<void> loginWithCode(String code) async {
    try {
      String auth = await _backend.loginWithCode(code);
      final storage = FlutterSecureStorage();
      await storage.write(key: 'auth', value: auth);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      rethrow;
    }
  }

  Future<void> restoreAuthFromStorage() async {
    try {
      final storage = FlutterSecureStorage();
      String? auth = await storage.read(key: 'auth');
      if (auth != null) {
        await _backend.restoreAuth(auth);
      } else {
        throw Exception('No auth token found in storage');
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      rethrow;
    }
  }

  /// Deletes the stored auth token so the next launch requires login again.
  /// Debug-only usage: see the Settings page's "Clear auth token" button.
  Future<void> clearAuth() async {
    final storage = FlutterSecureStorage();
    await storage.delete(key: 'auth');
  }

  Future<List<int>?> getOwnedGames() async {
    try {
      return await _backend.getOwnedGames();
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return null;
    }
  }

  Future<List<GameBuild>?> getBuilds(int gameId) async {
    try {
      return await _backend.getGameBuilds(gameId);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return null;
    }
  }

  Future<String?> getGameName(int gameId) =>
      _gameNameCache.putIfAbsent(gameId, () => _fetchGameName(gameId));

  Future<String?> _fetchGameName(int gameId) async {
    try {
      return await _backend.getGameTitle(gameId);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return null;
    }
  }

  Future<List<DownloadableProduct>?> getProducts(
    int gameId,
    String buildName,
  ) async {
    try {
      // Backend param is named `buildId` but the Rust side takes the
      // build's version name, not its id.
      return await _backend.getDownloadableProducts(
        gameId: gameId,
        buildName: buildName,
      );
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return null;
    }
  }

  Future<Stream<VerificationProgress>?> verifyGameFiles(
    int gameId,
    String path,
    String buildName,
    List<String> productIds,
  ) async {
    try {
      if (_verificationStreams.containsKey(gameId)) {
        return _verificationStreams[gameId];
      }
      var stream = _backend.verifyDownload(
        gameId: gameId,
        path: path,
        buildName: buildName,
        selectedProducts: productIds,
      );
      _verificationStreams[gameId] = stream;
      return stream;
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return null;
    }
  }

  /// Drops the cached verification stream for [gameId] so the game can be
  /// re-verified (e.g. after a repair completes).
  void clearVerificationStream(int gameId) {
    _verificationStreams.remove(gameId);
  }

  Future<Stream<RepairProgress>?> repairGameFiles(
    int gameId,
    String path,
    String buildName,
    List<String> productIds,
  ) async {
    try {
      if (_repairStreams.containsKey(gameId)) {
        return _repairStreams[gameId];
      }
      var stream = _backend.repairDownload(
        gameId: gameId,
        path: path,
        buildName: buildName,
        selectedProducts: productIds,
      );
      _repairStreams[gameId] = stream;
      return stream;
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return null;
    }
  }

  Future<Stream<DownloadProgress>?> downloadGameFiles(
    int gameId,
    String path,
    String buildName,
    List<String> productIds,
  ) async {
    try {
      if (_downloadStreams.containsKey(gameId)) {
        return _downloadStreams[gameId];
      }
      var stream = _backend.downloadGame(
        gameId: gameId,
        path: path,
        buildName: buildName,
        selectedProducts: productIds,
      );
      _downloadStreams[gameId] = stream;
      return stream;
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return null;
    }
  }

  Future<List<ProtonRelease>?> getProtonReleases(int page) async {
    try {
      return await _backend.getProtonReleases(page);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return null;
    }
  }

  Future<Stream<ProtonDownloadProgress>?> downloadProtonRelease(
    ProtonRelease release,
    String path,
  ) async {
    try {
      final tag = release.tagName;
      if (_protonDownloadStreams.containsKey(tag)) {
        return _protonDownloadStreams[tag];
      }
      var stream = _backend.downloadProtonRelease(release: release, path: path);
      _protonDownloadStreams[tag] = stream;
      return stream;
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return null;
    }
  }

  /// Drops the cached download stream for [tag] so the same release can be
  /// downloaded again, e.g. after a failed attempt.
  void clearProtonDownloadStream(String tag) {
    _protonDownloadStreams.remove(tag);
  }

  Future<SaveAuthIds?> getSaveAuthIds(int gameId) async {
    try {
      return await _backend.getSaveAuthIds(gameId);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return null;
    }
  }

  Future<CloudSaveConfig?> getSaveRemoteConfig(String clientId) async {
    try {
      return await _backend.getSaveRemoteConfig(clientId);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return null;
    }
  }

  Future<List<CloudSaveFile>?> getSaveFileList(
    String clientId,
    String clientSecret,
  ) async {
    try {
      return await _backend.getSaveFileList(
        clientId: clientId,
        clientSecret: clientSecret,
      );
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return null;
    }
  }

  /// Streams the download of a single cloud save file to [path]. Unlike the
  /// download/repair/Proton streams, this isn't cached — save syncs consume
  /// each per-file stream once, sequentially, from [SavesNotifier].
  Stream<SaveTransferProgress> downloadSaveFile({
    required CloudSaveFile saveFile,
    required String clientId,
    required String clientSecret,
    required String path,
  }) {
    return _backend.downloadSave(
      saveFile: saveFile,
      clientId: clientId,
      clientSecret: clientSecret,
      path: path,
    );
  }

  /// Streams the upload of a single local file at [path] to [urlPath] in
  /// cloud storage. Not cached — see [downloadSaveFile].
  Stream<SaveTransferProgress> uploadSaveFile({
    required String clientId,
    required String clientSecret,
    required String path,
    required String urlPath,
  }) {
    return _backend.uploadSave(
      clientId: clientId,
      clientSecret: clientSecret,
      path: path,
      urlPath: urlPath,
    );
  }
}

final gogStateProvider = Provider<GogState>((ref) {
  final instance = GogState(RealGogBackend(GogdlApi()));
  ref.onDispose(() => instance._backend.dispose());
  return instance;
}, name: 'gogStateProvider');
