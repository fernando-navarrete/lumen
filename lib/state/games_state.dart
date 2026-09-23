import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/app_paths.dart';
import 'package:lumen/state/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lumen/common/gog_error.dart';

enum GameStatus { downloading, downloaded, notInstalled }

/// Sentinel default for nullable [GameConfig.copyWith] parameters, so
/// "argument omitted" (keep existing value) can be told apart from
/// "argument explicitly passed as null" (clear the field) — Dart's normal
/// `param ?? this.field` copyWith pattern can't express the latter, which
/// previously forced hand-rebuilding [GameConfig] in a couple of setters and
/// silently dropped whichever fields that rebuild forgot to carry over.
const _unset = Object();

class GameConfig {
  final GameStatus status;
  final String selectedBuild;
  final Set<int> productIds;
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

  /// Command prepended to the Proton invocation at launch, e.g.
  /// `["gamescope", "-f", "--"]`; empty means launch Proton directly.
  final List<String> launchWrapper;

  GameConfig({
    required this.status,
    required this.selectedBuild,
    Set<int>? productIds,
    this.installPath,
    this.protonVersion,
    this.protonPrefixPath,
    this.executable,
    List<String>? launchArgs,
    Map<String, String>? envVars,
    List<String>? launchWrapper,
  }) : productIds = productIds != null
           ? Set<int>.from(productIds)
           : <int>{},
       launchArgs = launchArgs != null
           ? List<String>.from(launchArgs)
           : const [],
       envVars = envVars != null
           ? Map<String, String>.from(envVars)
           : const {},
       launchWrapper = launchWrapper != null
           ? List<String>.from(launchWrapper)
           : const [];

  /// Nullable fields (`installPath`, `protonVersion`, `protonPrefixPath`,
  /// `executable`) default to the [_unset] sentinel rather than `null`, so
  /// omitting them keeps the existing value while explicitly passing `null`
  /// clears them — see [_unset].
  GameConfig copyWith({
    GameStatus? status,
    String? selectedBuild,
    Set<int>? productIds,
    Object? installPath = _unset,
    Object? protonVersion = _unset,
    Object? protonPrefixPath = _unset,
    Object? executable = _unset,
    List<String>? launchArgs,
    Map<String, String>? envVars,
    List<String>? launchWrapper,
  }) {
    return GameConfig(
      status: status ?? this.status,
      selectedBuild: selectedBuild ?? this.selectedBuild,
      productIds: productIds ?? this.productIds,
      installPath: identical(installPath, _unset)
          ? this.installPath
          : installPath as String?,
      protonVersion: identical(protonVersion, _unset)
          ? this.protonVersion
          : protonVersion as String?,
      protonPrefixPath: identical(protonPrefixPath, _unset)
          ? this.protonPrefixPath
          : protonPrefixPath as String?,
      executable: identical(executable, _unset)
          ? this.executable
          : executable as String?,
      launchArgs: launchArgs ?? this.launchArgs,
      envVars: envVars ?? this.envVars,
      launchWrapper: launchWrapper ?? this.launchWrapper,
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

  Set<int> getProductIds(int gameId) {
    return Set<int>.from(games[gameId]?.productIds ?? <int>{});
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

  List<String> getLaunchWrapper(int gameId) {
    return List<String>.from(
      games[gameId]?.launchWrapper ?? const <String>[],
    );
  }
}

class GamesNotifier extends Notifier<GamesState> {
  late final SharedPreferences _prefs;

  @override
  GamesState build() {
    _prefs = ref.read(sharedPreferencesProvider);
    return _load();
  }

  /// Changes [gameId]'s selected build, preserving the rest of its config
  /// (status, install path, products, Proton override, executable, launch
  /// settings, ...). Callers that need to re-sync an installed game against
  /// the new build (e.g. the Builds tab) are responsible for starting a
  /// repair themselves — this only records the selection.
  void setSelectedBuild(int gameId, String buildName) {
    final existing = state.games[gameId];
    if (existing != null && existing.selectedBuild == buildName) {
      return;
    }
    final updated = existing != null
        ? existing.copyWith(selectedBuild: buildName)
        : GameConfig(status: GameStatus.notInstalled, selectedBuild: buildName);
    _update(gameId, updated);
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

  void setProductIds(int gameId, Set<int> productIds) {
    final existing = state.games[gameId];
    if (existing == null) {
      return;
    }
    _update(gameId, existing.copyWith(productIds: productIds));
  }

  void addProductId(int gameId, int productId) {
    final existing = state.games[gameId];
    if (existing == null) {
      return;
    }
    if (existing.productIds.contains(productId)) {
      return;
    }
    final updated = Set<int>.from(existing.productIds)..add(productId);
    _update(gameId, existing.copyWith(productIds: updated));
  }

  void toggleProductId(int gameId, int productId) {
    final existing = state.games[gameId];
    if (existing == null) {
      return;
    }
    final updated = Set<int>.from(existing.productIds);
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
    _update(gameId, existing.copyWith(protonVersion: tag));
  }

  /// Clears the Proton-GE override of every game pinned to [tag], so they
  /// fall back to the global default — call after [tag] is uninstalled.
  void clearProtonVersion(String tag) {
    final games = {...state.games};
    var changed = false;
    state.games.forEach((gameId, config) {
      if (config.protonVersion == tag) {
        games[gameId] = config.copyWith(protonVersion: null);
        changed = true;
      }
    });
    if (!changed) {
      return;
    }
    state = GamesState(games);
    _persist();
  }

  /// Sets [gameId]'s launch executable, relative to its install path; pass
  /// null to clear it back to "not resolved yet" (the Play flow will
  /// re-scan the install directory).
  void setExecutable(int gameId, String? executable) {
    final existing = state.games[gameId];
    if (existing == null) {
      return;
    }
    _update(gameId, existing.copyWith(executable: executable));
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

  void setLaunchWrapper(int gameId, List<String> launchWrapper) {
    final existing = state.games[gameId];
    if (existing == null) {
      return;
    }
    _update(gameId, existing.copyWith(launchWrapper: launchWrapper));
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
        'launchWrapper': config.launchWrapper,
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
      final launchWrapper = entry['launchWrapper'] as List<dynamic>?;
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
          // Product ids used to be persisted as strings (pre product-id
          // migration); tolerate either shape so a prefs file written by an
          // older build doesn't crash on load.
          productIds: productIds
              ?.map((id) => id is int ? id : int.parse(id as String))
              .toSet(),
          installPath: entry['installPath'] as String?,
          protonVersion: entry['protonVersion'] as String?,
          protonPrefixPath: entry['protonPrefixPath'] as String?,
          executable: entry['executable'] as String?,
          launchArgs: launchArgs?.map((arg) => arg as String).toList(),
          envVars: envVars?.map((key, value) => MapEntry(key, value as String)),
          launchWrapper: launchWrapper?.map((arg) => arg as String).toList(),
        ),
      );
    });
  }

  void _persist() {
    try {
      _prefs.setString('games', _encodeGames(state.games));
    } catch (e) {
      logGogError(e);
    }
  }

  /// Loads persisted game config synchronously from the already-resolved
  /// [_prefs] instance. Called from [build] so the notifier never emits an
  /// empty state that a mutation (or a launch) could read/persist over,
  /// clobbering real data — see [sharedPreferencesProvider].
  GamesState _load() {
    final gamesJson = _prefs.getString('games');
    if (gamesJson == null) {
      return const GamesState.empty();
    }
    try {
      return GamesState(_decodeGames(gamesJson));
    } catch (e) {
      logGogError(e);
      return const GamesState.empty();
    }
  }

  /// Wipes all SharedPreferences and the in-memory game config. Debug-only
  /// usage: see the Settings page's "Clear SharedPreferences" button.
  Future<void> clear() async {
    state = const GamesState.empty();
    await _prefs.clear();
  }
}

final gamesStateProvider = NotifierProvider<GamesNotifier, GamesState>(
  GamesNotifier.new,
  name: 'gamesStateProvider',
);
