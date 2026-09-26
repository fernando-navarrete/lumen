import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/app_paths.dart';
import 'package:lumen/state/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lumen/common/gog_error.dart';

/// [paused] is a download stopped by the user (or interrupted) whose partial
/// files are still on disk at [GameConfig.pendingInstallPath], resumable
/// through a repair.
enum GameStatus { downloading, paused, downloaded, notInstalled }

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

  /// Where an unfinished download is writing (or was writing, once paused).
  /// Set when a download starts and cleared on completion (when
  /// `markInstalled` moves it to [installPath]), on cancel and on uninstall,
  /// so every reader of [installPath] can keep treating a path as "installed".
  final String? pendingInstallPath;

  /// Whether [pendingInstallPath] was empty or missing when the download
  /// started, i.e. everything in it is the download's own and cancelling may
  /// delete the whole folder.
  final bool ownsPendingInstallDir;

  /// Per-game Proton-GE tag override; null means "use the global default
  /// selected in Settings".
  final String? protonVersion;

  /// The Proton prefix directory for this game, created on first launch.
  final String? protonPrefixPath;

  /// The user's executable override, relative to [installPath]: only ever
  /// set from a picker. Null means "auto" — `LaunchResolver` resolves GOG's
  /// play task, then a scan, on every launch, and never persists the result.
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
    this.pendingInstallPath,
    this.ownsPendingInstallDir = false,
    this.protonVersion,
    this.protonPrefixPath,
    this.executable,
    List<String>? launchArgs,
    Map<String, String>? envVars,
    List<String>? launchWrapper,
  }) : productIds = productIds != null ? Set<int>.from(productIds) : <int>{},
       launchArgs = launchArgs != null
           ? List<String>.from(launchArgs)
           : const [],
       envVars = envVars != null ? Map<String, String>.from(envVars) : const {},
       launchWrapper = launchWrapper != null
           ? List<String>.from(launchWrapper)
           : const [];

  /// Nullable fields (`installPath`, `pendingInstallPath`, `protonVersion`, `protonPrefixPath`,
  /// `executable`) default to the [_unset] sentinel rather than `null`, so
  /// omitting them keeps the existing value while explicitly passing `null`
  /// clears them — see [_unset].
  GameConfig copyWith({
    GameStatus? status,
    String? selectedBuild,
    Set<int>? productIds,
    Object? installPath = _unset,
    Object? pendingInstallPath = _unset,
    bool? ownsPendingInstallDir,
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
      pendingInstallPath: identical(pendingInstallPath, _unset)
          ? this.pendingInstallPath
          : pendingInstallPath as String?,
      ownsPendingInstallDir:
          ownsPendingInstallDir ?? this.ownsPendingInstallDir,
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

  /// Ids of the games whose Proton-GE override is [tag].
  List<int> gamesPinnedTo(String tag) => [
    for (final entry in games.entries)
      if (entry.value.protonVersion == tag) entry.key,
  ];

  String? getInstallPath(int gameId) {
    return games[gameId]?.installPath;
  }

  String? getPendingInstallPath(int gameId) {
    return games[gameId]?.pendingInstallPath;
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
    return List<String>.from(games[gameId]?.launchWrapper ?? const <String>[]);
  }
}

class GamesNotifier extends Notifier<GamesState> {
  late final SharedPreferences _prefs;

  /// How long a debounced setter (see [_update]'s `debounce` parameter)
  /// waits for more edits before writing to prefs.
  static const persistDebounce = Duration(milliseconds: 500);

  /// The current version of the persisted `games` JSON format. Every save
  /// is written as `{"version": gamesSchemaVersion, "games": {...}}`;
  /// [_load] upgrades anything older through [_migrations] before decoding
  /// it, so a format change is a numbered migration step instead of the
  /// type-sniffing [_decodeGames] used to do (the productId string/int
  /// fallback). Bump this and append a step to [_migrations] whenever the
  /// per-game JSON shape changes.
  static const gamesSchemaVersion = 2;

  /// `_migrations[n]` upgrades a raw games map (gameId string -> entry map,
  /// both still JSON-shaped, i.e. pre-[_decodeGames]) from version `n` to
  /// `n + 1`. [_load] runs every step from the stored version up to
  /// [gamesSchemaVersion] before handing the result to [_decodeGames],
  /// which only ever has to read the current format.
  static final List<Map<String, dynamic> Function(Map<String, dynamic>)>
  _migrations = [
    // v0 -> v1: productIds used to sometimes be persisted as strings
    // (pre product-id migration); coerce them all to ints so
    // _decodeGames can read productIds strictly.
    (games) => games.map((gameId, value) {
      final entry = Map<String, dynamic>.from(value as Map<String, dynamic>);
      final productIds = entry['productIds'] as List<dynamic>?;
      if (productIds != null) {
        entry['productIds'] = productIds
            .map((id) => id is int ? id : int.parse(id as String))
            .toList();
      }
      return MapEntry(gameId, entry);
    }),
    // v1 -> v2: downloads became resumable, with their path in
    // `pendingInstallPath`. A v1 `downloading` entry has no path to resume
    // from, so it goes back to notInstalled (what _decodeGames used to do).
    (games) => games.map((gameId, value) {
      final entry = Map<String, dynamic>.from(value as Map<String, dynamic>);
      if (entry['status'] == 'downloading') {
        entry['status'] = 'notInstalled';
      }
      return MapEntry(gameId, entry);
    }),
  ];

  Timer? _persistTimer;

  /// Mirrors `state.games` as of the last [_update] call. [_persist] writes
  /// from this instead of reading [state] directly, because Riverpod
  /// forbids touching `state`/`ref` from inside an `onDispose` callback —
  /// [flushPendingPersist] is one, registered below, to catch a debounced
  /// edit still pending when the notifier itself is torn down — and a
  /// plain field has no such restriction.
  Map<int, GameConfig> _lastGames = const {};

  /// Whether a debounced edit is waiting for [_persistTimer] to fire.
  bool _hasPendingPersist = false;

  @override
  GamesState build() {
    _prefs = ref.read(sharedPreferencesProvider);
    final loaded = _load();
    _lastGames = loaded.games;
    // A debounced edit still pending when the notifier is torn down (e.g.
    // app exit, or the container disposing in tests) must not be lost;
    // flushPendingPersist cancels _persistTimer as part of writing it.
    ref.onDispose(flushPendingPersist);
    return loaded;
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
            pendingInstallPath: null,
            ownsPendingInstallDir: false,
          )
        : GameConfig(
            status: GameStatus.downloaded,
            selectedBuild: '',
            installPath: installPath,
          );
    _update(gameId, updated);
  }

  /// Records that a download for [gameId] is starting in [path]. [ownsDir]
  /// says the folder was empty or missing beforehand, so cancelling may
  /// delete all of it.
  void beginInstall(int gameId, String path, {required bool ownsDir}) {
    final existing = state.games[gameId];
    final updated =
        (existing ??
                GameConfig(status: GameStatus.downloading, selectedBuild: ''))
            .copyWith(
              status: GameStatus.downloading,
              pendingInstallPath: path,
              ownsPendingInstallDir: ownsDir,
            );
    _update(gameId, updated);
  }

  /// Forgets an unfinished download: back to notInstalled with no pending
  /// path. Leaves [GameConfig.installPath] and the rest of the config alone.
  void clearPendingInstall(int gameId) {
    final existing = state.games[gameId];
    if (existing == null) {
      return;
    }
    _update(
      gameId,
      existing.copyWith(
        status: GameStatus.notInstalled,
        pendingInstallPath: null,
        ownsPendingInstallDir: false,
      ),
    );
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

  /// Sets [gameId]'s executable override, relative to its install path;
  /// pass null to reset it to auto (see [GameConfig.executable]).
  void setExecutable(int gameId, String? executable) {
    final existing = state.games[gameId];
    if (existing == null) {
      return;
    }
    _update(gameId, existing.copyWith(executable: executable));
  }

  // These three are driven directly by keystrokes in GameSettingsTab's text
  // fields (one call per character typed), so their prefs write is
  // debounced rather than immediate — see _update's `debounce` parameter.
  // The in-memory state still updates on every call.

  void setLaunchArgs(int gameId, List<String> launchArgs) {
    final existing = state.games[gameId];
    if (existing == null) {
      return;
    }
    _update(gameId, existing.copyWith(launchArgs: launchArgs), debounce: true);
  }

  void setEnvVars(int gameId, Map<String, String> envVars) {
    final existing = state.games[gameId];
    if (existing == null) {
      return;
    }
    _update(gameId, existing.copyWith(envVars: envVars), debounce: true);
  }

  void setLaunchWrapper(int gameId, List<String> launchWrapper) {
    final existing = state.games[gameId];
    if (existing == null) {
      return;
    }
    _update(
      gameId,
      existing.copyWith(launchWrapper: launchWrapper),
      debounce: true,
    );
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

  /// Updates in-memory state immediately. The prefs write either happens
  /// right away, or — with [debounce] — is delayed by [persistDebounce] so a
  /// burst of keystroke-driven calls (see setLaunchArgs/setEnvVars/
  /// setLaunchWrapper) collapses into a single whole-JSON write instead of
  /// one per character. An immediate (non-debounced) call always writes the
  /// latest state, so it carries along any edit still waiting in the
  /// debounce window.
  void _update(int gameId, GameConfig config, {bool debounce = false}) {
    state = GamesState({...state.games, gameId: config});
    _lastGames = state.games;
    debounce ? _schedulePersist() : _persist();
  }

  void _schedulePersist() {
    _hasPendingPersist = true;
    _persistTimer?.cancel();
    _persistTimer = Timer(persistDebounce, () {
      _persistTimer = null;
      _persist();
    });
  }

  /// Writes a debounced edit to prefs immediately instead of waiting for
  /// [persistDebounce] to elapse. Called when leaving the settings tab
  /// (`GameSettingsTab.dispose`) and when this notifier itself is disposed,
  /// so a pending edit is never silently dropped.
  void flushPendingPersist() {
    if (!_hasPendingPersist) {
      return;
    }
    _persist();
  }

  String _encodeGames(Map<int, GameConfig> map) {
    final stringKeyed = map.map(
      (gameId, config) => MapEntry(gameId.toString(), {
        'status': config.status.name,
        'selectedBuild': config.selectedBuild,
        'productIds': config.productIds.toList(),
        'installPath': config.installPath,
        'pendingInstallPath': config.pendingInstallPath,
        'ownsPendingInstallDir': config.ownsPendingInstallDir,
        'protonVersion': config.protonVersion,
        'protonPrefixPath': config.protonPrefixPath,
        'executable': config.executable,
        'launchArgs': config.launchArgs,
        'envVars': config.envVars,
        'launchWrapper': config.launchWrapper,
      }),
    );
    return jsonEncode({'version': gamesSchemaVersion, 'games': stringKeyed});
  }

  /// Decodes a raw games map already at [gamesSchemaVersion] (i.e. after
  /// [_load] has run it through [_migrations]) into [GameConfig]s.
  Map<int, GameConfig> _decodeGames(Map<String, dynamic> games) {
    return games.map((gameId, value) {
      final entry = value as Map<String, dynamic>;
      final productIds = entry['productIds'] as List<dynamic>?;
      final launchArgs = entry['launchArgs'] as List<dynamic>?;
      final envVars = entry['envVars'] as Map<String, dynamic>?;
      final launchWrapper = entry['launchWrapper'] as List<dynamic>?;
      // A game left mid-download when the app was killed has no live job, so
      // it can't stay "Installing…" forever. With a `pendingInstallPath` its
      // partial files are still there, so it becomes a resumable `paused`
      // game; without one there is nothing to resume, so it's notInstalled.
      final status = GameStatus.values.byName(entry['status'] as String);
      final pendingInstallPath = entry['pendingInstallPath'] as String?;
      return MapEntry(
        int.parse(gameId),
        GameConfig(
          status: status == GameStatus.downloading
              ? (pendingInstallPath != null
                    ? GameStatus.paused
                    : GameStatus.notInstalled)
              : status,
          selectedBuild: entry['selectedBuild'] as String,
          productIds: productIds?.map((id) => id as int).toSet(),
          installPath: entry['installPath'] as String?,
          pendingInstallPath: pendingInstallPath,
          ownsPendingInstallDir:
              entry['ownsPendingInstallDir'] as bool? ?? false,
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
    _persistTimer?.cancel();
    _persistTimer = null;
    _hasPendingPersist = false;
    try {
      _prefs.setString('games', _encodeGames(_lastGames));
    } catch (e) {
      logGogError(e);
    }
  }

  /// Loads persisted game config synchronously from the already-resolved
  /// [_prefs] instance. Called from [build] so the notifier never emits an
  /// empty state that a mutation (or a launch) could read/persist over,
  /// clobbering real data — see [sharedPreferencesProvider].
  ///
  /// Pre-[v1.1.5] prefs are a bare `{gameId: entry}` map with no version at
  /// all — a real gameId key can never be the string `"version"`, so that
  /// shape is unambiguously version 0. Anything else is expected to be the
  /// `{"version": n, "games": {...}}` envelope; [_migrations] upgrades it to
  /// [gamesSchemaVersion] before [_decodeGames] reads it. A stored version
  /// newer than [gamesSchemaVersion] (e.g. after a downgrade) is decoded
  /// as-is on a best-effort basis — new fields are usually just additions —
  /// and falls back to empty state like corrupt JSON if that throws.
  GamesState _load() {
    final gamesJson = _prefs.getString('games');
    if (gamesJson == null) {
      return const GamesState.empty();
    }
    try {
      final decoded = jsonDecode(gamesJson);
      int version;
      Map<String, dynamic> games;
      if (decoded is Map<String, dynamic> && decoded['version'] is int) {
        version = decoded['version'] as int;
        games = Map<String, dynamic>.from(
          decoded['games'] as Map<String, dynamic>,
        );
      } else {
        version = 0;
        games = Map<String, dynamic>.from(decoded as Map<String, dynamic>);
      }
      while (version < gamesSchemaVersion) {
        games = _migrations[version](games);
        version++;
      }
      return GamesState(_decodeGames(games));
    } catch (e) {
      logGogError(e);
      return const GamesState.empty();
    }
  }

  /// Wipes all SharedPreferences and the in-memory game config. Debug-only
  /// usage: see the Settings page's "Clear SharedPreferences" button.
  Future<void> clear() async {
    // Drop any pending debounced write first, or its timer firing after
    // prefs.clear() would resurrect the cleared games.
    _persistTimer?.cancel();
    _persistTimer = null;
    _hasPendingPersist = false;
    _lastGames = const {};
    state = const GamesState.empty();
    await _prefs.clear();
  }
}

final gamesStateProvider = NotifierProvider<GamesNotifier, GamesState>(
  GamesNotifier.new,
  name: 'gamesStateProvider',
);
