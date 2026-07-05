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
}

final gogStateProvider = Provider<GogState>((ref) {
  final instance = GogState(Gog());
  ref.onDispose(() => instance._gog.dispose());
  return instance;
}, name: 'gogStateProvider');
