import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GameStatus { downloading, downloaded, notInstalled }

class GameConfig {
  final GameStatus status;
  final String selectedBuild;
  final Set<String> productIds;

  GameConfig({
    required this.status,
    required this.selectedBuild,
    Set<String>? productIds,
  }) : productIds = productIds != null
           ? Set<String>.from(productIds)
           : <String>{};

  GameConfig copyWith({
    GameStatus? status,
    String? selectedBuild,
    Set<String>? productIds,
  }) {
    return GameConfig(
      status: status ?? this.status,
      selectedBuild: selectedBuild ?? this.selectedBuild,
      productIds: productIds ?? this.productIds,
    );
  }
}

class GamesState {
  final HashMap<int, GameConfig> _games = HashMap<int, GameConfig>();

  String? getSelectedBuild(int gameId) {
    return _games[gameId]?.selectedBuild;
  }

  void setSelectedBuild(int gameId, String buildName) {
    _games[gameId] = GameConfig(
      status: GameStatus.notInstalled,
      selectedBuild: buildName,
    );
    persist();
  }

  GameStatus getGameStatus(int gameId) {
    return _games[gameId]?.status ?? GameStatus.notInstalled;
  }

  void setGameStatus(int gameId, GameStatus status) {
    final existing = _games[gameId];
    if (existing == null) {
      return;
    }
    _games[gameId] = existing.copyWith(status: status);
    persist();
  }

  Set<String> getProductIds(int gameId) {
    return Set<String>.from(_games[gameId]?.productIds ?? <String>{});
  }

  void setProductIds(int gameId, Set<String> productIds) {
    final existing = _games[gameId];
    if (existing == null) {
      return;
    }
    _games[gameId] = existing.copyWith(productIds: productIds);
    persist();
  }

  void toggleProductId(int gameId, String productId) {
    final existing = _games[gameId];
    if (existing == null) {
      return;
    }
    final updated = Set<String>.from(existing.productIds);
    if (!updated.remove(productId)) {
      updated.add(productId);
    }
    _games[gameId] = existing.copyWith(productIds: updated);
    persist();
  }

  String _encodeGames(HashMap<int, GameConfig> map) {
    final stringKeyed = map.map(
      (gameId, config) => MapEntry(gameId.toString(), {
        'status': config.status.name,
        'selectedBuild': config.selectedBuild,
        'productIds': config.productIds.toList(),
      }),
    );
    return jsonEncode(stringKeyed);
  }

  void _decodeGames(String json, HashMap<int, GameConfig> target) {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    target.clear();
    target.addAll(
      decoded.map((gameId, value) {
        final entry = value as Map<String, dynamic>;
        final productIds = entry['productIds'] as List<dynamic>?;
        return MapEntry(
          int.parse(gameId),
          GameConfig(
            status: GameStatus.values.byName(entry['status'] as String),
            selectedBuild: entry['selectedBuild'] as String,
            productIds: productIds?.map((id) => id as String).toSet(),
          ),
        );
      }),
    );
  }

  void persist() {
    SharedPreferences.getInstance().then((prefs) {
      try {
        prefs.setString('games', _encodeGames(_games));
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
      }
    });
  }

  void load() {
    SharedPreferences.getInstance().then((prefs) {
      String? gamesJson = prefs.getString('games');
      if (gamesJson != null) {
        try {
          _decodeGames(gamesJson, _games);
        } catch (e) {
          if (kDebugMode) {
            print(e);
          }
          _games.clear();
        }
      }
    });
  }
}

final gamesStateProvider = Provider<GamesState>((ref) {
  final instance = GamesState();
  instance.load();
  return instance;
}, name: 'gamesStateProvider');
