import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gogdl2_flutter_bridge/gogdl2_flutter_bridge.dart';

class GogState {
  final Gog _gog;
  final HashMap<int, Stream<VerificationStream>> _verificationStreams =
      HashMap();
  final HashMap<int, Stream<RepairStream>> _repairStreams = HashMap();
  final HashMap<int, Stream<DownloadStream>> _downloadStreams = HashMap();
  final HashMap<String, Stream<ProtonDownloadStream>> _protonDownloadStreams =
      HashMap();

  GogState(this._gog);

  String getLoginUrl() {
    return _gog.getLoginUrl();
  }

  Future<void> refreshAuthWithCallback() async {
    try {
      await _gog.refreshAuthWithCallback(
        callback: (auth) async {
          final storage = FlutterSecureStorage();
          await storage.write(key: 'auth', value: auth);
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print(e);
        throw Exception(e);
      }
    }
  }

  Future<String> getGameBackgroundLink(int gameId) async {
    try {
      String link = await _gog.getBackgroundImageLink(gameId: gameId);
      return link;
    } catch (e) {
      if (kDebugMode) {
        print(e);
        throw Exception(e);
      }
      return '';
    }
  }

  Future<String> getGameBoxartLink(int gameId) async {
    try {
      String link = await _gog.getGameBoxartLink(gameId: gameId);
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
      String summary = await _gog.getGameSummary(gameId: gameId);
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
      List<String> screenshots = await _gog.getGameScreenshots(gameId: gameId);
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
      String auth = await _gog.loginWithCode(code: code);
      final storage = FlutterSecureStorage();
      await storage.write(key: 'auth', value: auth);
    } catch (e) {
      if (kDebugMode) {
        print(e);
        throw Exception(e);
      }
    }
  }

  Future<void> restoreAuthFromStorage() async {
    try {
      final storage = FlutterSecureStorage();
      String? auth = await storage.read(key: 'auth');
      if (auth != null) {
        await _gog.restoreAuthFromString(token: auth);
      } else {
        throw Exception('No auth token found in storage');
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
        throw Exception(e);
      }
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
      return await _gog.getOwnedGames();
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return null;
    }
  }

  Future<List<GameBuild>?> getBuilds(int gameId) async {
    try {
      return await _gog.getGameBuilds(gameId: gameId);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return null;
    }
  }

  Future<String?> getGameName(int gameId) async {
    try {
      return await _gog.getGameTitle(gameId: gameId);
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
      // Bridge param is named `buildId` but the Rust side takes the build's
      // version name, not its id.
      return await _gog.getDownloadableProducts(
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

  Future<Stream<VerificationStream>?> verifyGameFiles(
    int gameId,
    String path,
    String buildName,
    List<String> productIds,
  ) async {
    try {
      if (_verificationStreams.containsKey(gameId)) {
        return _verificationStreams[gameId];
      }
      var stream = _gog.verifyDownload(
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

  Future<Stream<RepairStream>?> repairGameFiles(
    int gameId,
    String path,
    String buildName,
    List<String> productIds,
  ) async {
    try {
      if (_repairStreams.containsKey(gameId)) {
        return _repairStreams[gameId];
      }
      var stream = _gog.repairDownload(
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

  Future<Stream<DownloadStream>?> downloadGameFiles(
    int gameId,
    String path,
    String buildName,
    List<String> productIds,
  ) async {
    try {
      if (_downloadStreams.containsKey(gameId)) {
        return _downloadStreams[gameId];
      }
      var stream = _gog.downloadGame(
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
      return await _gog.getProtonReleases(page: page);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return null;
    }
  }

  Future<Stream<ProtonDownloadStream>?> downloadProtonRelease(
    ProtonRelease release,
    String path,
  ) async {
    try {
      final tag = release.tagName();
      if (_protonDownloadStreams.containsKey(tag)) {
        return _protonDownloadStreams[tag];
      }
      var stream = _gog.downloadProtonRelease(release: release, path: path);
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
      return await _gog.getSaveAuthIds(gameId: gameId);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return null;
    }
  }

  Future<CloudSaveConfig?> getSaveRemoteConfig(String clientId) async {
    try {
      return await _gog.getSaveRemoteConfig(clientId: clientId);
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
      return await _gog.getSaveFileList(
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
  Stream<SaveDownloadStream> downloadSaveFile({
    required CloudSaveFile saveFile,
    required String clientId,
    required String clientSecret,
    required String path,
  }) {
    return _gog.downloadSave(
      saveFile: saveFile,
      clientId: clientId,
      clientSecret: clientSecret,
      path: path,
    );
  }

  /// Streams the upload of a single local file at [path] to [urlPath] in
  /// cloud storage. Not cached — see [downloadSaveFile].
  Stream<SaveUploadStream> uploadSaveFile({
    required String clientId,
    required String clientSecret,
    required String path,
    required String urlPath,
  }) {
    return _gog.uploadSave(
      clientId: clientId,
      clientSecret: clientSecret,
      path: path,
      urlPath: urlPath,
    );
  }
}

final gogStateProvider = Provider<GogState>((ref) {
  final instance = GogState(Gog());
  ref.onDispose(() => instance._gog.dispose());
  return instance;
}, name: 'gogStateProvider');
