import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/save_paths.dart';
import 'package:lumen/components/centered_loader.dart';
import 'package:lumen/components/primary_button.dart';
import 'package:lumen/components/section_card.dart';
import 'package:lumen/state/downloads_state.dart' show TaskStatus;
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/state/saves_state.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

/// Per-game cloud save tab: shows whether GOG cloud saves are supported,
/// the resolved local save directory, and lets the user pull every remote
/// save file down or push every local one up. There's no automatic merge —
/// the bridge exposes no remote timestamp/hash to compare against, so
/// Download and Upload are separate, explicit actions. Progress for a
/// triggered sync shows as a card in the Downloads tab's "Cloud Saves"
/// section (see [SavesNotifier]).
class SavesTab extends ConsumerStatefulWidget {
  const SavesTab({super.key, required this.gameId});

  final int gameId;

  @override
  ConsumerState<SavesTab> createState() => _SavesTabState();
}

class _SavesTabState extends ConsumerState<SavesTab> {
  bool _loading = true;
  bool _supported = false;
  String? _localPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  @override
  void didUpdateWidget(covariant SavesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gameId != widget.gameId) {
      setState(() {
        _loading = true;
        _supported = false;
        _localPath = null;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
    }
  }

  Future<void> _resolve() async {
    final gogState = ref.read(gogStateProvider);
    final gamesState = ref.read(gamesStateProvider);
    final gameId = widget.gameId;

    final installPath = gamesState.getInstallPath(gameId);

    final authIds = await gogState.getSaveAuthIds(gameId);
    if (authIds == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = "Couldn't reach cloud save configuration for this game";
        });
      }
      return;
    }

    final config = await gogState.getSaveRemoteConfig(authIds.clientId);
    if (config == null || !config.isSupported) {
      if (mounted) {
        setState(() {
          _loading = false;
          _supported = false;
        });
      }
      return;
    }

    String? localPath;
    if (installPath != null) {
      final prefixPath = ref
          .read(gamesStateProvider.notifier)
          .ensureProtonPrefix(gameId);
      try {
        localPath = resolveSaveRoot(
          config.knownFolder,
          config.relativePath,
          prefixPath: prefixPath,
          installPath: installPath,
        );
      } catch (_) {
        localPath = null;
      }
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _supported = true;
        _localPath = localPath;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameId = widget.gameId;
    final installed =
        ref.watch(gamesStateProvider).getInstallPath(gameId) != null;
    final task = ref.watch(
      savesStateProvider.select((state) => state.taskFor(gameId)),
    );
    final syncing = task?.status == TaskStatus.running;

    if (_loading) {
      return const CenteredLoader();
    }

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.md,
          children: [
            SectionCard(
              title: "Cloud saves",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xs,
                children: [
                  Text(
                    _error ??
                        (_supported
                            ? "Supported"
                            : "This game doesn't support GOG cloud saves"),
                    style: AppText.bodyMedium(
                      color: _error != null ? AppColors.error : Colors.white,
                      weight: FontWeight.w600,
                    ),
                  ),
                  if (_supported)
                    Text(
                      !installed
                          ? "Install the game to resolve its local save path"
                          : _localPath ??
                                "Unable to resolve the local save path",
                      style: AppText.cardDesc(),
                    ),
                ],
              ),
            ),
            if (_supported)
              Row(
                spacing: AppSpacing.sm,
                children: [
                  PrimaryButton.icon(
                    icon: Icons.cloud_download,
                    label: "Download",
                    glowing: true,
                    enabled: installed && !syncing,
                    onTap: () => _start(context, download: true),
                  ),
                  PrimaryButton.icon(
                    icon: Icons.cloud_upload,
                    label: "Upload",
                    glowing: false,
                    enabled: installed && !syncing,
                    onTap: () => _start(context, download: false),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _start(BuildContext context, {required bool download}) async {
    final notifier = ref.read(savesStateProvider.notifier);
    if (download) {
      await notifier.downloadSaves(widget.gameId);
    } else {
      await notifier.uploadSaves(widget.gameId);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            download
                ? "Downloading saves — check the Downloads tab for progress"
                : "Uploading saves — check the Downloads tab for progress",
          ),
        ),
      );
    }
  }
}
