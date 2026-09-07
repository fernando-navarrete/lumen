import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl_flutter/gogdl_flutter.dart';
import 'package:lumen/common/format.dart';
import 'package:lumen/components/app_dropdown.dart';
import 'package:lumen/components/centered_loader.dart';
import 'package:lumen/components/panel.dart';
import 'package:lumen/components/primary_button.dart';
import 'package:lumen/components/section_card.dart';
import 'package:lumen/state/downloads_state.dart' show TaskStatus;
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
      if (releases != null) {
        _releases.addAll(releases);
        _nextPage++;
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
                                  "No releases loaded",
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
                      if (_loadedOnce)
                        PrimaryButton(
                          enabled: !_loading,
                          onTap: _loadMore,
                          child: Text(
                            _loading ? "Loading…" : "Load more",
                            style: AppText.button(color: Colors.white),
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
                formatBytesBigint(release.downloadSize),
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
