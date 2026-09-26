import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/app_paths.dart';
import 'package:lumen/common/directory_size.dart';
import 'package:lumen/common/format.dart';
import 'package:path/path.dart' as p;
import 'package:lumen/components/app_dropdown.dart';
import 'package:lumen/components/centered_loader.dart';
import 'package:lumen/components/panel.dart';
import 'package:lumen/components/primary_button.dart';
import 'package:lumen/components/section_card.dart';
import 'package:lumen/models/proton_release.dart';
import 'package:lumen/state/downloads_state.dart' show TaskStatus;
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/launch_state.dart';
import 'package:lumen/state/proton_state.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

/// Settings section for managing Proton-GE: choose the app-wide default
/// version from a dropdown of installed versions, and open a dialog to
/// browse/install releases from GloriousEggroll's GitHub repo. Per-game
/// overrides live on that game's own Settings tab.
class ProtonManagerSection extends ConsumerWidget {
  const ProtonManagerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final protonState = ref.watch(protonStateProvider);

    return SectionCard(
      title: "Default compatibility layer",
      description: "Proton-GE version used for any game set to “Default”.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppDropdown<String>(
            value: protonState.defaultVersion,
            placeholder: "No versions installed — install one below.",
            entries: [
              for (final tag in protonState.installedTags)
                AppDropdownEntry(value: tag, label: tag),
            ],
            onChanged: protonState.installedTags.isEmpty
                ? null
                : (tag) =>
                      ref.read(protonStateProvider.notifier).setDefault(tag!),
          ),
          if (protonState.installedTags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text("Installed versions", style: AppText.sectionLabel),
            const SizedBox(height: AppSpacing.xs),
            for (final tag in protonState.installedTags)
              _InstalledRow(tag: tag, protonState: protonState),
          ],
          const SizedBox(height: AppSpacing.md),
          PrimaryButton.icon(
            icon: Icons.download,
            label: "Manage / install versions…",
            glowing: false,
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => const _ProtonManagerDialog(),
            ),
          ),
        ],
      ),
    );
  }
}

/// One installed version with its Remove action. Remove opens
/// [_RemoveProtonDialog] and is disabled while a running game uses the tag.
///
/// There is no "running download" case to guard: an installed tag never has
/// a running task, since `downloadRelease` returns early for one.
class _InstalledRow extends ConsumerWidget {
  const _InstalledRow({required this.tag, required this.protonState});

  final String tag;
  final ProtonState protonState;

  bool _inUse(WidgetRef ref) {
    final games = ref.watch(gamesStateProvider);
    final launch = ref.watch(launchStateProvider);
    return launch.games.keys.any((gameId) {
      if (!launch.isActive(gameId)) {
        return false;
      }
      final effective =
          games.getProtonVersion(gameId) ?? protonState.defaultVersion;
      return effective == tag;
    });
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final path = protonState.pathFor(tag);
    if (path == null) {
      return;
    }
    final pinned = ref.read(gamesStateProvider).gamesPinnedTo(tag).length;
    final deleteFiles = await showDialog<bool>(
      context: context,
      builder: (_) => _RemoveProtonDialog(
        tag: tag,
        path: path,
        pinnedGames: pinned,
        isDefault: protonState.defaultVersion == tag,
      ),
    );
    if (deleteFiles == null) {
      return;
    }
    try {
      await ref
          .read(protonStateProvider.notifier)
          .removeVersion(tag, deleteFiles: deleteFiles);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Couldn't remove $tag: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inUse = _inUse(ref);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  protonState.defaultVersion == tag ? "$tag (default)" : tag,
                  style: AppText.bodyMedium(
                    color: Colors.white,
                    weight: FontWeight.w600,
                  ),
                ),
                Text(
                  protonState.pathFor(tag) ?? '',
                  style: AppText.caption(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Tooltip(
            message: inUse ? "In use by a running game" : "Remove $tag",
            child: TextButton.icon(
              onPressed: inUse ? null : () => _remove(context, ref),
              icon: Icon(
                Icons.delete_outline,
                color: inUse ? AppColors.textMuted : AppColors.error,
              ),
              label: Text(
                "Remove",
                style: AppText.button(
                  color: inUse ? AppColors.textMuted : AppColors.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirmation for removing an installed version. Pops `true` to remove
/// and delete its files, `false` to remove and keep them, or `null` on
/// cancel. Deleting starts checked only for a release under
/// [protonInstallDir]; a folder the user chose stays unchecked and warns.
class _RemoveProtonDialog extends StatefulWidget {
  const _RemoveProtonDialog({
    required this.tag,
    required this.path,
    required this.pinnedGames,
    required this.isDefault,
  });

  final String tag;
  final String path;
  final int pinnedGames;
  final bool isDefault;

  @override
  State<_RemoveProtonDialog> createState() => _RemoveProtonDialogState();
}

class _RemoveProtonDialogState extends State<_RemoveProtonDialog> {
  late final bool _custom = !p.isWithin(protonInstallDir(), widget.path);
  late bool _deleteFiles = !_custom;
  bool _sizeLoaded = false;
  int? _size;

  @override
  void initState() {
    super.initState();
    directorySize(widget.path).then((size) {
      if (mounted) {
        setState(() {
          _sizeLoaded = true;
          _size = size;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sizeText = !_sizeLoaded
        ? " (…)"
        : _size == null
        ? ""
        : " (${formatBytes(_size!)})";
    final notes = [
      if (widget.pinnedGames > 0)
        "${widget.pinnedGames} game(s) use this version and will switch to "
            "the default.",
      if (widget.isDefault)
        "This is the default version; no default will be set.",
    ];
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Remove ${widget.tag}?', style: AppText.sectionLabel),
              const SizedBox(height: AppSpacing.sm),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _deleteFiles,
                onChanged: (v) => setState(() => _deleteFiles = v ?? false),
                title: Text(
                  "Also delete its files$sizeText",
                  style: AppText.meta(color: Colors.white),
                ),
              ),
              if (_custom)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    "This folder is outside Lumen's Proton directory; you "
                    "chose it when installing: ${widget.path}",
                    style: AppText.meta(color: AppColors.warning),
                  ),
                ),
              for (final note in notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    note,
                    style: AppText.meta(color: AppColors.textSecondary),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: AppSpacing.sm,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: AppText.button(color: AppColors.textSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_deleteFiles),
                    child: Text(
                      'Remove',
                      style: AppText.button(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog listing installable Proton-GE releases (paginated from GitHub)
/// alongside install progress/status. Opened from [ProtonManagerSection].
class _ProtonManagerDialog extends ConsumerStatefulWidget {
  const _ProtonManagerDialog();

  @override
  ConsumerState<_ProtonManagerDialog> createState() =>
      _ProtonManagerDialogState();
}

class _ProtonManagerDialogState extends ConsumerState<_ProtonManagerDialog> {
  final List<ProtonRelease> _releases = [];
  int _nextPage = 1;
  bool _loading = false;
  bool _loadedOnce = false;
  bool _failed = false;
  bool _reachedEnd = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
  }

  Future<void> _loadMore() async {
    if (_loading) {
      return;
    }
    setState(() => _loading = true);
    final releases = await ref
        .read(protonStateProvider.notifier)
        .fetchReleases(_nextPage);
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _loadedOnce = true;
      if (releases == null) {
        _failed = true;
      } else {
        _failed = false;
        if (releases.isEmpty) {
          _reachedEnd = true;
        } else {
          _releases.addAll(releases);
          _nextPage++;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final protonState = ref.watch(protonStateProvider);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Install Proton-GE versions",
                      style: AppText.cardTitle(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_releases.isEmpty)
                        _loading
                            ? const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: AppSpacing.md,
                                ),
                                child: CenteredLoader(),
                              )
                            : Panel(
                                child: Text(
                                  _failed
                                      ? "Couldn't load releases"
                                      : _reachedEnd
                                      ? "No releases available"
                                      : "No releases loaded",
                                  style: AppText.bodyMedium(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              )
                      else
                        Column(
                          spacing: AppSpacing.sm,
                          children: [
                            for (final release in _releases)
                              _ReleaseRow(
                                release: release,
                                protonState: protonState,
                              ),
                          ],
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      if (_loadedOnce && !_reachedEnd)
                        PrimaryButton(
                          enabled: !_loading,
                          onTap: _loadMore,
                          child: Text(
                            _loading
                                ? "Loading…"
                                : _failed
                                ? "Retry"
                                : "Load more",
                            style: AppText.button(color: Colors.white),
                          ),
                        )
                      else if (_loadedOnce &&
                          _reachedEnd &&
                          _releases.isNotEmpty)
                        Text(
                          "No more releases",
                          style: AppText.caption(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReleaseRow extends ConsumerWidget {
  const _ReleaseRow({required this.release, required this.protonState});

  final ProtonRelease release;
  final ProtonState protonState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tag = release.tagName;
    final installed = protonState.isInstalled(tag);
    final task = protonState.taskFor(tag);
    final showProgress = task != null && task.status != TaskStatus.failed;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xs,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tag,
                  style: AppText.bodyMedium(
                    color: Colors.white,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                formatBytes(release.downloadSize),
                style: AppText.caption(color: AppColors.textSecondary),
              ),
            ],
          ),
          if (installed)
            Text("Installed", style: AppText.caption(color: AppColors.primary))
          else if (showProgress)
            _ProgressRow(task: task)
          else
            Align(
              alignment: Alignment.centerRight,
              child: PrimaryButton.icon(
                icon: Icons.download,
                label: task?.status == TaskStatus.failed ? "Retry" : "Install",
                glowing: false,
                onTap: () => ref
                    .read(protonStateProvider.notifier)
                    .downloadRelease(release),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.task});

  final ProtonTask task;

  @override
  Widget build(BuildContext context) {
    final double? progress = task.total > 0
        ? task.transferred / task.total
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xs,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.control),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.border08,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
        Text(
          _statusText(),
          style: AppText.caption(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  String _statusText() {
    switch (task.stage) {
      case "extracting":
        return "Extracting…";
      case "downloading":
      default:
        return "Downloading… ${formatBytes(task.transferred)}"
            "/${formatBytes(task.total)}";
    }
  }
}
