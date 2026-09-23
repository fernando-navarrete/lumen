import 'package:dir_picker/dir_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/executable_finder.dart';
import 'package:lumen/components/executable_picker_dialog.dart';
import 'package:lumen/components/primary_button.dart';
import 'package:lumen/models/downloadable_product.dart';
import 'package:lumen/models/game_build.dart';
import 'package:lumen/state/downloads_state.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/state/launch_state.dart';
import 'package:lumen/state/proton_state.dart';

/// The status-driven action row for one game: nothing while installing,
/// Play once installed, otherwise Install/Import. Owns the preload of the
/// default build + products that gates Install/Import, and the full launch
/// flow (Proton resolution, executable picking, prefix creation).
class GameActionButtons extends ConsumerStatefulWidget {
  const GameActionButtons({
    super.key,
    required this.gameId,
    this.large = false,
    this.onSelectBuild,
  });

  final int gameId;

  /// Hero-sized buttons (library hero, game header).
  final bool large;

  /// Called when an action needs the user to pick a build (e.g. the
  /// installed build is missing or no longer offered by GOG) — typically
  /// switches to the Builds tab. Left null wherever there's no tab to
  /// switch to (the library hero).
  final VoidCallback? onSelectBuild;

  @override
  ConsumerState<GameActionButtons> createState() => _GameActionButtonsState();
}

class _GameActionButtonsState extends ConsumerState<GameActionButtons> {
  /// Whether preloading the default build + products has finished, gating
  /// the Install/Import buttons so they always have something to act on.
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _preload());
  }

  @override
  void didUpdateWidget(covariant GameActionButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gameId != widget.gameId) {
      setState(() {
        _ready = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _preload());
    }
  }

  GameBuild _latestBuild(List<GameBuild> builds) => builds.reduce(
    (a, b) => b.releaseDateTimestamp > a.releaseDateTimestamp ? b : a,
  );

  /// Preloads the default build (latest) and products (all) for
  /// [widget.gameId], but only fills in defaults when nothing has been
  /// saved yet — a prior user choice is left untouched. Never picks a build
  /// for an already-installed game: the files on disk were built from
  /// whatever build was recorded (or none), and guessing "latest" here
  /// could silently record a build that doesn't match them — see
  /// [_checkBuild] for how a missing/stale build is surfaced instead.
  Future<void> _preload() async {
    final gogState = ref.read(gogStateProvider);
    final gamesNotifier = ref.read(gamesStateProvider.notifier);
    final gameId = widget.gameId;
    final installed =
        ref.read(gamesStateProvider).getGameStatus(gameId) ==
        GameStatus.downloaded;

    // Re-read gamesStateProvider after each mutation below — it's an
    // immutable snapshot, so a stale local would miss updates the notifier
    // just made (e.g. addProductId below).
    String? buildName = ref.read(gamesStateProvider).getSelectedBuild(gameId);
    if (!installed && (buildName == null || buildName.isEmpty)) {
      final builds = await gogState.getBuilds(gameId);
      if (!mounted) return;
      if (builds != null && builds.isNotEmpty) {
        buildName = _latestBuild(builds).versionName;
        gamesNotifier.setSelectedBuild(gameId, buildName);
      }
    }

    if (buildName != null &&
        buildName.isNotEmpty &&
        ref.read(gamesStateProvider).getProductIds(gameId).isEmpty) {
      final products = await gogState.getProducts(gameId, buildName);
      if (!mounted) return;
      for (final product in products ?? const <DownloadableProduct>[]) {
        gamesNotifier.addProductId(gameId, product.id);
      }
    }

    if (mounted) {
      setState(() {
        _ready =
            (buildName != null && buildName.isNotEmpty) &&
            ref.read(gamesStateProvider).getProductIds(gameId).isNotEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameId = widget.gameId;
    final gamesState = ref.watch(gamesStateProvider);
    final GameStatus status = gamesState.getGameStatus(gameId);
    final bool installing = status == GameStatus.downloading;
    final bool installed = status == GameStatus.downloaded;
    final bool running = ref.watch(
      launchStateProvider.select((state) => state.isActive(gameId)),
    );
    ref.listen<LaunchState>(launchStateProvider, (previous, next) {
      final prevStatus = previous?.gameFor(gameId)?.status;
      final game = next.gameFor(gameId);
      if (game?.status == LaunchStatus.failed &&
          prevStatus != LaunchStatus.failed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(game?.error ?? "Failed to launch game")),
        );
      }
    });

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: _buildActionButtons(
        context,
        gameId,
        gamesState,
        installing: installing,
        installed: installed,
        running: running,
      ),
    );
  }

  /// Builds the action row based on the game's status: nothing while
  /// installing, Play (or "Running…" while launched) once installed,
  /// otherwise the Install/Import pair.
  List<Widget> _buildActionButtons(
    BuildContext context,
    int gameId,
    GamesState gamesState, {
    required bool installing,
    required bool installed,
    required bool running,
  }) {
    if (installing) {
      return const [];
    }
    if (installed) {
      return [
        PrimaryButton.icon(
          enabled: !running,
          onTap: () => _onPlay(context, gameId, gamesState),
          glowing: true,
          large: widget.large,
          icon: running ? Icons.hourglass_top : Icons.play_arrow,
          label: running ? "Running…" : "Play",
        ),
        PrimaryButton.icon(
          icon: Icons.fact_check,
          label: "Verify",
          glowing: false,
          large: widget.large,
          onTap: () => _onVerify(context, gameId, gamesState),
        ),
      ];
    }
    return [
      PrimaryButton.icon(
        enabled: _ready,
        glowing: true,
        large: widget.large,
        icon: Icons.arrow_downward,
        label: "Install",
        onTap: () async {
          final PickedLocation? location = await DirPicker.pick();
          if (location == null) {
            return;
          }

          final String path = location.uri!.toFilePath();
          final List<int> productIds = gamesState
              .getProductIds(gameId)
              .toList();
          final String buildName = gamesState.getSelectedBuild(gameId) ?? "";
          if (productIds.isEmpty) {
            return;
          }

          await ref
              .read(downloadsStateProvider.notifier)
              .startDownload(
                gameId,
                path: path,
                buildName: buildName,
                productIds: productIds,
              );

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Downloading — check the Downloads tab for progress",
                ),
              ),
            );
          }
        },
      ),
      PrimaryButton.icon(
        icon: Icons.folder_open,
        label: "Import",
        glowing: false,
        large: widget.large,
        enabled: _ready,
        onTap: () async {
          final PickedLocation? location = await DirPicker.pick();
          if (location == null) {
            return;
          }

          final String path = location.uri!.toFilePath();
          final List<int> productIds = gamesState
              .getProductIds(gameId)
              .toList();
          final String buildName = gamesState.getSelectedBuild(gameId) ?? "";
          if (productIds.isEmpty) {
            return;
          }

          await ref
              .read(downloadsStateProvider.notifier)
              .startVerification(
                gameId,
                path: path,
                buildName: buildName,
                productIds: productIds,
              );

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Verifying files — check the Downloads tab for progress",
                ),
              ),
            );
          }
        },
      ),
    ];
  }

  /// Returns an error message if [buildName] can't be used to verify/repair
  /// an installed game, or null if it looks usable. An empty name means
  /// nothing was ever selected; a non-empty one that isn't in GOG's current
  /// build list means the build was delisted or renamed after install —
  /// either way the bridge would otherwise fail immediately (it looks the
  /// build up by name) with no useful error surfaced to the user. A failed
  /// [GogState.getBuilds] call (e.g. offline) returns null here too, so the
  /// action proceeds and any real failure comes back through the task's
  /// [ActivityTask.error] instead.
  Future<String?> _checkBuild(int gameId, String buildName) async {
    if (buildName.isEmpty) {
      return "No build selected for this game — pick the installed build "
          "in the Builds tab";
    }
    final gogState = ref.read(gogStateProvider);
    final builds = await gogState.getBuilds(gameId);
    if (builds == null) {
      return null;
    }
    if (!builds.any((b) => b.versionName == buildName)) {
      return 'Build "$buildName" is no longer offered by GOG — pick one in '
          'the Builds tab';
    }
    return null;
  }

  /// Re-checks an installed game's files against the manifest, reusing its
  /// already-persisted install path/build/products instead of prompting via
  /// [DirPicker] the way the not-installed "Import" flow does.
  Future<void> _onVerify(
    BuildContext context,
    int gameId,
    GamesState gamesState,
  ) async {
    void showMessage(String message) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }

    final String? path = gamesState.getInstallPath(gameId);
    if (path == null) {
      showMessage("This game has no install path recorded");
      return;
    }
    final String buildName = gamesState.getSelectedBuild(gameId) ?? "";
    final buildError = await _checkBuild(gameId, buildName);
    if (buildError != null) {
      if (!mounted) return;
      showMessage(buildError);
      widget.onSelectBuild?.call();
      return;
    }
    final List<int> productIds = gamesState.getProductIds(gameId).toList();
    if (productIds.isEmpty) {
      showMessage("This game has no products selected to verify");
      return;
    }

    await ref
        .read(downloadsStateProvider.notifier)
        .startVerificationForInstalled(
          gameId,
          path: path,
          buildName: buildName,
          productIds: productIds,
        );

    showMessage("Verifying files — check the Downloads tab for progress");
  }

  /// Resolves the effective Proton-GE version (per-game override, else the
  /// global default from Settings), the game's executable, and its Proton
  /// prefix directory (created on first launch), then hands off to
  /// [LaunchNotifier] to actually spawn the game via Proton.
  Future<void> _onPlay(
    BuildContext context,
    int gameId,
    GamesState gamesState,
  ) async {
    void showMessage(String message) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }

    final defaultVersion = ref.read(protonStateProvider).defaultVersion;
    final protonVersion = gamesState.getProtonVersion(gameId) ?? defaultVersion;
    if (protonVersion == null) {
      showMessage(
        "No Proton-GE version installed — install one in Settings first",
      );
      return;
    }

    final protonPath = ref.read(protonStateProvider).pathFor(protonVersion);
    if (protonPath == null) {
      showMessage('Proton-GE version "$protonVersion" is no longer installed');
      return;
    }

    final installPath = gamesState.getInstallPath(gameId);
    if (installPath == null) {
      showMessage("This game has no install path recorded");
      return;
    }

    final executable = await _resolveExecutable(
      context,
      gameId,
      installPath,
      gamesState,
    );
    if (executable == null) {
      return;
    }

    final prefixPath = ref
        .read(gamesStateProvider.notifier)
        .ensureProtonPrefix(gameId);

    await ref
        .read(launchStateProvider.notifier)
        .launchGame(
          gameId,
          protonPath: protonPath,
          installPath: installPath,
          executable: executable,
          prefixPath: prefixPath,
          launchArgs: gamesState.getLaunchArgs(gameId),
          envVars: gamesState.getEnvVars(gameId),
          launchWrapper: gamesState.getLaunchWrapper(gameId),
        );
  }

  /// Resolves [gameId]'s launch executable: returns the stored override if
  /// set, otherwise scans [installPath] for candidates, auto-picking a lone
  /// match or prompting via [showExecutablePicker] when there's more than
  /// one, and persists the resolved choice. Returns null (after showing a
  /// snackbar) if nothing usable was found or the user canceled the picker.
  Future<String?> _resolveExecutable(
    BuildContext context,
    int gameId,
    String installPath,
    GamesState gamesState,
  ) async {
    final existing = gamesState.getExecutable(gameId);
    if (existing != null) {
      return existing;
    }

    final candidates = findExecutables(installPath);
    if (candidates.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No launchable .exe found in $installPath")),
        );
      }
      return null;
    }

    String? chosen;
    if (candidates.length == 1) {
      chosen = candidates.first;
    } else {
      if (!context.mounted) {
        return null;
      }
      chosen = await showExecutablePicker(
        context,
        candidates: candidates,
        confirmLabel: "Launch",
      );
      if (chosen == null) {
        return null;
      }
    }

    ref.read(gamesStateProvider.notifier).setExecutable(gameId, chosen);
    return chosen;
  }
}
