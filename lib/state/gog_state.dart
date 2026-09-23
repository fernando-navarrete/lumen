import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gogdl_flutter/gogdl_flutter.dart';
import 'package:lumen/state/gog_backend.dart';
import 'package:lumen/state/gogdl_backend.dart';
import 'package:lumen/common/gog_error.dart';

class GogState {
  final GogBackend _backend;
  final HashMap<int, Stream<VerifyDownloadProgress>> _verificationStreams =
      HashMap();
  final HashMap<int, Stream<RepairGameProgress>> _repairStreams = HashMap();
  final HashMap<int, Stream<DownloadGameProgress>> _downloadStreams =
      HashMap();
  final HashMap<String, Stream<ProtonDownloadProgress>> _protonDownloadStreams =
      HashMap();
  final HashMap<int, Stream<DownloadSavesProgress>> _saveDownloadStreams =
      HashMap();
  final HashMap<int, Stream<UploadSavesProgress>> _saveUploadStreams =
      HashMap();

  /// Names and boxart links are static for a session, but callers (e.g. the
  /// Downloads page task cards) call these getters on every rebuild —
  /// several times a second while a download is in flight. Caching the
  /// Future itself (not just its resolved value) means a FutureBuilder fed
  /// the same Future instance across rebuilds stays in its "has data" state
  /// instead of resetting to pending and re-issuing the bridge call.
  final HashMap<int, Future<String?>> _gameNameCache = HashMap();
  final HashMap<int, Future<String>> _boxartLinkCache = HashMap();

  /// The bridge's owned-games list is filtered to real games server-side
  /// (since `gogdl_flutter` v1.1.3) by looking up every owned product on
  /// `gamesdb.gog.com`, unordered and uncached — so it's both slow (one
  /// request per owned product) and shuffles order between calls. Cache the
  /// resolved, sorted list for a stable grid order and a cheap tab switch;
  /// [invalidateOwnedGames] clears it for a manual Retry.
  Future<List<int>?>? _ownedGamesCache;

  /// Caches the in-flight/completed registration of the token-refresh
  /// callback (see [_ensureTokenRefreshCallback]) so it's only registered
  /// once per [GogState], no matter how many auth calls trigger it.
  Future<void>? _tokenRefreshRegistration;

  GogState(this._backend);

  String getLoginUrl() {
    try {
      return _backend.getLoginUrl();
    } on GogError catch (e) {
      logGogError(e);
      return '';
    }
  }

  Future<String> getGameBackgroundLink(int gameId) async {
    try {
      String link = await _backend.getBackgroundImageLink(gameId);
      return link;
    } catch (e) {
      logGogError(e);
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
      logGogError(e);
      return '';
    }
  }

  Future<String> getGameSummary(int gameId) async {
    try {
      String summary = await _backend.getGameSummary(gameId);
      return summary;
    } catch (e) {
      logGogError(e);
      return '';
    }
  }

  Future<List<String>> getGameScreenshots(int gameId) async {
    try {
      List<String> screenshots = await _backend.getGameScreenshots(gameId);
      return screenshots;
    } catch (e) {
      logGogError(e);
      return [];
    }
  }

  Future<void> loginWithCode(String code) async {
    try {
      await _ensureTokenRefreshCallback();
      String auth = await _backend.loginWithCode(code);
      final storage = FlutterSecureStorage();
      await storage.write(key: 'auth', value: auth);
    } catch (e) {
      logGogError(e);
      rethrow;
    }
  }

  /// Restores the stored auth token. Returns `false` when none is stored (a
  /// normal first run); throws on a real failure (keyring or bridge error).
  Future<bool> restoreAuthFromStorage() async {
    try {
      await _ensureTokenRefreshCallback();
      final storage = FlutterSecureStorage();
      String? auth = await storage.read(key: 'auth');
      if (auth == null) {
        return false;
      }
      await _backend.restoreAuth(auth);
      return true;
    } catch (e) {
      logGogError(e);
      rethrow;
    }
  }

  /// Registers the backend's token-refresh callback exactly once for this
  /// [GogState], persisting every refreshed auth JSON to the same storage
  /// key used by [loginWithCode]/[restoreAuthFromStorage]. Without this, a
  /// stored token goes stale the first time the backend rotates the refresh
  /// token, since that rotation is only ever reported through this callback.
  Future<void> _ensureTokenRefreshCallback() =>
      _tokenRefreshRegistration ??= _registerTokenRefreshCallback();

  Future<void> _registerTokenRefreshCallback() async {
    try {
      await _backend.setTokenRefreshCallback((auth) async {
        final storage = FlutterSecureStorage();
        await storage.write(key: 'auth', value: auth);
      });
    } catch (e) {
      logGogError(e);
      // Let the next auth call retry registration instead of leaving the
      // app permanently without the callback for this session.
      _tokenRefreshRegistration = null;
    }
  }

  /// Deletes the stored auth token so the next launch requires login again.
  /// Debug-only usage: see the Settings page's "Clear auth token" button.
  Future<void> clearAuth() async {
    try {
      await _backend.removeTokenRefreshCallback();
    } catch (e) {
      logGogError(e);
    }
    _tokenRefreshRegistration = null;
    final storage = FlutterSecureStorage();
    await storage.delete(key: 'auth');
  }

  Future<List<int>?> getOwnedGames() =>
      _ownedGamesCache ??= _fetchOwnedGames();

  /// Drops the cached owned-games list so the next [getOwnedGames] call
  /// re-fetches, for a manual Retry.
  void invalidateOwnedGames() {
    _ownedGamesCache = null;
  }

  Future<List<int>?> _fetchOwnedGames() async {
    try {
      final owned = await _backend.getOwnedGames();
      if (owned.isEmpty) {
        // A per-product gamesdb lookup failure silently drops that game
        // upstream, so an empty result may just be transient — don't pin it
        // behind the cache, so a Retry actually hits the network again.
        _ownedGamesCache = null;
        return owned;
      }
      return owned.toList()..sort();
    } catch (e) {
      logGogError(e);
      // Don't pin a transient failure behind the cache — let the next call
      // (e.g. a Retry) try the network again.
      _ownedGamesCache = null;
      return null;
    }
  }

  Future<List<GameBuild>?> getBuilds(int gameId) async {
    try {
      return await _backend.getGameBuilds(gameId);
    } catch (e) {
      logGogError(e);
      return null;
    }
  }

  Future<String?> getGameName(int gameId) =>
      _gameNameCache.putIfAbsent(gameId, () => _fetchGameName(gameId));

  Future<String?> _fetchGameName(int gameId) async {
    try {
      return await _backend.getGameTitle(gameId);
    } catch (e) {
      logGogError(e);
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
      logGogError(e);
      return null;
    }
  }

  Future<Stream<VerifyDownloadProgress>?> verifyGameFiles(
    int gameId,
    String path,
    String buildName,
    List<int> productIds,
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
      logGogError(e);
      return null;
    }
  }

  /// Drops the cached verification stream for [gameId] so the game can be
  /// re-verified (e.g. after a repair completes).
  void clearVerificationStream(int gameId) {
    _verificationStreams.remove(gameId);
  }

  /// Drops the cached download stream for [gameId] so the game can be
  /// downloaded again, e.g. after a failed attempt.
  void clearDownloadStream(int gameId) {
    _downloadStreams.remove(gameId);
  }

  /// Drops the cached repair stream for [gameId] so the game can be
  /// repaired again, e.g. after a failed attempt.
  void clearRepairStream(int gameId) {
    _repairStreams.remove(gameId);
  }

  Future<Stream<RepairGameProgress>?> repairGameFiles(
    int gameId,
    String path,
    String buildName,
    List<int> productIds,
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
      logGogError(e);
      return null;
    }
  }

  Future<Stream<DownloadGameProgress>?> downloadGameFiles(
    int gameId,
    String path,
    String buildName,
    List<int> productIds,
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
      logGogError(e);
      return null;
    }
  }

  Future<List<ProtonRelease>?> getProtonReleases(int page) async {
    try {
      return await _backend.getProtonReleases(page);
    } on GogError catch (e) {
      logGogError(e);
      return null;
    }
  }

  Future<Stream<ProtonDownloadProgress>?> downloadProtonRelease(
    String tagName,
    String path,
  ) async {
    try {
      if (_protonDownloadStreams.containsKey(tagName)) {
        return _protonDownloadStreams[tagName];
      }
      var stream = _backend.downloadProtonRelease(tagName: tagName, path: path);
      _protonDownloadStreams[tagName] = stream;
      return stream;
    } catch (e) {
      logGogError(e);
      return null;
    }
  }

  /// Drops the cached download stream for [tag] so the same release can be
  /// downloaded again, e.g. after a failed attempt.
  void clearProtonDownloadStream(String tag) {
    _protonDownloadStreams.remove(tag);
  }

  Future<Stream<DownloadSavesProgress>?> downloadSaves(
    int gameId,
    String buildName,
    String prefix,
    String installPath,
  ) async {
    try {
      if (_saveDownloadStreams.containsKey(gameId)) {
        return _saveDownloadStreams[gameId];
      }
      var stream = _backend.downloadSaves(
        gameId: gameId,
        buildName: buildName,
        prefix: prefix,
        installPath: installPath,
      );
      _saveDownloadStreams[gameId] = stream;
      return stream;
    } catch (e) {
      logGogError(e);
      return null;
    }
  }

  Future<Stream<UploadSavesProgress>?> uploadSaves(
    int gameId,
    String buildName,
    String prefix,
    String installPath,
  ) async {
    try {
      if (_saveUploadStreams.containsKey(gameId)) {
        return _saveUploadStreams[gameId];
      }
      var stream = _backend.uploadSaves(
        gameId: gameId,
        buildName: buildName,
        prefix: prefix,
        installPath: installPath,
      );
      _saveUploadStreams[gameId] = stream;
      return stream;
    } catch (e) {
      logGogError(e);
      return null;
    }
  }

  /// Drops the cached save download stream so [downloadSaves] starts a fresh
  /// sync — needed before every re-run, since a finished stream can't be
  /// listened to again.
  void clearSaveDownloadStream(int gameId) {
    _saveDownloadStreams.remove(gameId);
  }

  /// Drops the cached save upload stream. See [clearSaveDownloadStream].
  void clearSaveUploadStream(int gameId) {
    _saveUploadStreams.remove(gameId);
  }
}

final gogStateProvider = Provider<GogState>((ref) {
  final instance = GogState(GogdlBackend(GogdlApi()));
  ref.onDispose(() => instance._backend.dispose());
  return instance;
}, name: 'gogStateProvider');
