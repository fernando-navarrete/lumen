import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl2_flutter/common/app_paths.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GameStatus { downloading, downloaded, notInstalled }

class GameConfig {
  final GameStatus status;
  final String selectedBuild;
  final Set<String> productIds;
  final String? installPath;

  /// Per-game Proton-GE tag override; null means "use the global default
  /// selected in Settings".
  final String? protonVersion;

  /// The Proton prefix directory for this game, created on first launch.
  final String? protonPrefixPath;

  /// Path to the game's executable, relative to [installPath]. Null means
  /// "not resolved yet" — the Play flow scans [installPath] for candidates.
  final String? executable;

  /// Extra arguments appended after the executable path at launch.
  final List<String> launchArgs;

  /// Extra environment variables set on the launched game process.
  final Map<String, String> envVars;

  GameConfig({
    required this.status,
    required this.selectedBuild,
    Set<String>? productIds,
    this.installPath,
    this.protonVersion,
    this.protonPrefixPath,
    this.executable,
    List<String>? launchArgs,
    Map<String, String>? envVars,
  }) : productIds = productIds != null
           ? Set<String>.from(productIds)
           : <String>{},
       launchArgs = launchArgs != null
           ? List<String>.from(launchArgs)
           : const [],
       envVars = envVars != null
           ? Map<String, String>.from(envVars)
           : const {};

  GameConfig copyWith({
    GameStatus? status,
    String? selectedBuild,
    Set<String>? productIds,
    String? installPath,
    String? protonVersion,
    String? protonPrefixPath,
    String? executable,
    List<String>? launchArgs,
    Map<String, String>? envVars,
  }) {
    return GameConfig(
      status: status ?? this.status,
      selectedBuild: selectedBuild ?? this.selectedBuild,
      productIds: productIds ?? this.productIds,
      installPath: installPath ?? this.installPath,
      protonVersion: protonVersion ?? this.protonVersion,
      protonPrefixPath: protonPrefixPath ?? this.protonPrefixPath,
      executable: executable ?? this.executable,
      launchArgs: launchArgs ?? this.launchArgs,
      envVars: envVars ?? this.envVars,
    );
  }
}

/// Immutable snapshot of per-game config, keyed by gameId. Read-only —
/// mutations go through [GamesNotifier] via `gamesStateProvider.notifier`.
class GamesState {
  final Map<int, GameConfig> games;

  const GamesState(this.games);

  const GamesState.empty() : games = const {};

  String? getSelectedBuild(int gameId) {
    return games[gameId]?.selectedBuild;
  }

  GameStatus getGameStatus(int gameId) {
    return games[gameId]?.status ?? GameStatus.notInstalled;
  }

  String? getInstallPath(int gameId) {
    return games[gameId]?.installPath;
  }

  String? getProtonVersion(int gameId) {
    return games[gameId]?.protonVersion;
  }

  String? getProtonPrefixPath(int gameId) {
    return games[gameId]?.protonPrefixPath;
  }

  Set<String> getProductIds(int gameId) {
    return Set<String>.from(games[gameId]?.productIds ?? <String>{});
  }

  String? getExecutable(int gameId) {
    return games[gameId]?.executable;
  }

  List<String> getLaunchArgs(int gameId) {
    return List<String>.from(games[gameId]?.launchArgs ?? const <String>[]);
  }

  Map<String, String> getEnvVars(int gameId) {
    return Map<String, String>.from(
      games[gameId]?.envVars ?? const <String, String>{},
    );
  }
}

class GamesNotifier extends Notifier<GamesState> {
  @override
  GamesState build() {
    _load();
    return const GamesState.empty();
  }

  void setSelectedBuild(int gameId, String buildName) {
    final existing = state.games[gameId];
    if (existing != null && existing.selectedBuild == buildName) {
      return;
    }
    _update(
      gameId,
      GameConfig(status: GameStatus.notInstalled, selectedBuild: buildName),
    );
  }

  void setGameStatus(int gameId, GameStatus status) {
    final existing = state.games[gameId];
    if (existing == null) {
      return;
    }
    _update(gameId, existing.copyWith(status: status));
  }

  /// Marks [gameId] as installed at [installPath], e.g. after a download,
  /// repair, or import completes successfully. Preserves the game's
  /// existing selected build and product ids.
  void markInstalled(int gameId, String installPath) {
    final existing = state.games[gameId];
    final updated = existing != null
        ? existing.copyWith(
            status: GameStatus.downloaded,
            installPath: installPath,
          )
        : GameConfig(
            status: GameStatus.downloaded,
            selectedBuild: '',
            installPath: installPath,
          );
    _update(gameId, updated);
  }

  void setProductIds(int gameId, Set<String> productIds) {
    final existing = state.games[gameId];
    if (existing == null) {
      return;
    }
    _update(gameId, existing.copyWith(productIds: productIds));
  }

  void addProductId(int gameId, String productId) {
    final existing = state.games[gameId];
    if (existing == null) {
      return;
    }
    if (existing.productIds.contains(productId)) {
      return;
    }
    final updated = Set<String>.from(existing.productIds)..add(productId);
    _update(gameId, existing.copyWith(productIds: updated));
  }

  void toggleProductId(int gameId, String productId) {
    final existing = state.games[gameId];
    if (existing == null) {
      return;
    }
    final updated = Set<String>.from(existing.productIds);
    if (!updated.remove(productId)) {
      updated.add(productId);
    }
    _update(gameId, existing.copyWith(productIds: updated));
  }

  /// Sets [gameId]'s Proton-GE override; pass null to fall back to the
  /// global default selected in Settings.
  void setProtonVersion(int gameId, String? tag) {
    final existing = state.games[gameId];
    if (existing == null) {
      return;
    }
    // copyWith can't null out a field (its `?? this.field` pattern only
    // ever keeps or replaces), so build the config directly here.
    _update(
      gameId,
      GameConfig(
        status: existing.status,
        selectedBuild: existing.selectedBuild,
        productIds: existing.productIds,
        installPath: existing.installPath,
        protonVersion: tag,
        protonPrefixPath: existing.protonPrefixPath,
      ),
    );
  }

  /// Sets [gameId]'s launch executable, relative to its install path; pass
  /// null to clear it back to "not resolved yet" (the Play flow will
  /// re-scan the install directory).
  void setExecutable(int gameId, String? executable) {
    final existing = state.games[gameId];
    if (existing == null) {
      return;
    }
    // copyWith can't null out a field (its `?? this.field` pattern only
    // ever keeps or replaces), so build the config directly here.
    _update(
      gameId,
      GameConfig(
        status: existing.status,
        selectedBuild: existing.selectedBuild,
        productIds: existing.productIds,
        installPath: existing.installPath,
        protonVersion: existing.protonVersion,
        protonPrefixPath: existing.protonPrefixPath,
        executable: executable,
        launchArgs: existing.launchArgs,
        envVars: existing.envVars,
      ),
    );
  }

  void setLaunchArgs(int gameId, List<String> launchArgs) {
    final existing = state.games[gameId];
    if (existing == null) {
      return;
    }
    _update(gameId, existing.copyWith(launchArgs: launchArgs));
  }

  void setEnvVars(int gameId, Map<String, String> envVars) {
    final existing = state.games[gameId];
    if (existing == null) {
      return;
    }
    _update(gameId, existing.copyWith(envVars: envVars));
  }

  /// Returns [gameId]'s Proton prefix directory, creating it (and the
  /// default `~/.local/share/lumen/prefixes/<gameId>` path, if none is set
  /// yet) on first launch.
  String ensureProtonPrefix(int gameId) {
    final existing = state.games[gameId];
    final existingPath = existing?.protonPrefixPath;
    if (existingPath != null) {
      return existingPath;
    }

    final path = protonPrefixDir(gameId);
    Directory(path).createSync(recursive: true);

    final updated = existing != null
        ? existing.copyWith(protonPrefixPath: path)
        : GameConfig(
            status: GameStatus.notInstalled,
            selectedBuild: '',
            protonPrefixPath: path,
          );
    _update(gameId, updated);
    return path;
  }

  void _update(int gameId, GameConfig config) {
    state = GamesState({...state.games, gameId: config});
    _persist();
  }

  String _encodeGames(Map<int, GameConfig> map) {
    final stringKeyed = map.map(
      (gameId, config) => MapEntry(gameId.toString(), {
        'status': config.status.name,
        'selectedBuild': config.selectedBuild,
        'productIds': config.productIds.toList(),
        'installPath': config.installPath,
        'protonVersion': config.protonVersion,
        'protonPrefixPath': config.protonPrefixPath,
        'executable': config.executable,
        'launchArgs': config.launchArgs,
        'envVars': config.envVars,
      }),
    );
    return jsonEncode(stringKeyed);
  }

  Map<int, GameConfig> _decodeGames(String json) {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map((gameId, value) {
      final entry = value as Map<String, dynamic>;
      final productIds = entry['productIds'] as List<dynamic>?;
      final launchArgs = entry['launchArgs'] as List<dynamic>?;
      final envVars = entry['envVars'] as Map<String, dynamic>?;
      // A game left mid-download when the app was killed can't resume, so
      // it's coerced back to notInstalled rather than staying stuck showing
      // "Installing…"/Pause forever.
      final status = GameStatus.values.byName(entry['status'] as String);
      return MapEntry(
        int.parse(gameId),
        GameConfig(
          status: status == GameStatus.downloading
              ? GameStatus.notInstalled
              : status,
          selectedBuild: entry['selectedBuild'] as String,
          productIds: productIds?.map((id) => id as String).toSet(),
          installPath: entry['installPath'] as String?,
          protonVersion: entry['protonVersion'] as String?,
          protonPrefixPath: entry['protonPrefixPath'] as String?,
          executable: entry['executable'] as String?,
          launchArgs: launchArgs?.map((arg) => arg as String).toList(),
          envVars: envVars?.map((key, value) => MapEntry(key, value as String)),
        ),
      );
    });
  }

  void _persist() {
    SharedPreferences.getInstance().then((prefs) {
      try {
        prefs.setString('games', _encodeGames(state.games));
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
      }
    });
  }

  void _load() {
    SharedPreferences.getInstance().then((prefs) {
      String? gamesJson = prefs.getString('games');
      if (gamesJson != null) {
        try {
          state = GamesState(_decodeGames(gamesJson));
        } catch (e) {
          if (kDebugMode) {
            print(e);
          }
          state = const GamesState.empty();
        }
      }
    });
  }

  /// Wipes all SharedPreferences and the in-memory game config. Debug-only
  /// usage: see the Settings page's "Clear SharedPreferences" button.
  Future<void> clear() async {
    state = const GamesState.empty();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

final gamesStateProvider = NotifierProvider<GamesNotifier, GamesState>(
  GamesNotifier.new,
  name: 'gamesStateProvider',
);
