import 'package:dir_picker/dir_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl2_flutter/common/clickable_container.dart';
import 'package:gogdl2_flutter/common/format.dart';
import 'package:gogdl2_flutter/components/centered_loader.dart';
import 'package:gogdl2_flutter/components/panel.dart';
import 'package:gogdl2_flutter/components/primary_button.dart';
import 'package:gogdl2_flutter/state/downloads_state.dart' show TaskStatus;
import 'package:gogdl2_flutter/state/proton_state.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';
import 'package:gogdl2_flutter/theme/app_dimens.dart';
import 'package:gogdl2_flutter/theme/text_styles.dart';
import 'package:gogdl2_flutter_bridge/gogdl2_flutter_bridge.dart';

/// Settings section for managing Proton-GE: choose the app-wide default
/// version, and browse/install releases from GloriousEggroll's GitHub repo.
/// Per-game overrides live on that game's own Settings tab.
class ProtonManagerSection extends ConsumerStatefulWidget {
  const ProtonManagerSection({super.key});

  @override
  ConsumerState<ProtonManagerSection> createState() =>
      _ProtonManagerSectionState();
}

class _ProtonManagerSectionState extends ConsumerState<ProtonManagerSection> {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Proton", style: AppText.sectionLabel),
        const SizedBox(height: AppSpacing.sm),
        Text(
          "Default version",
          style: AppText.bodyMedium(color: Colors.white, weight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        _InstalledVersionsPanel(protonState: protonState),
        const SizedBox(height: AppSpacing.md),
        Text(
          "Available versions",
          style: AppText.bodyMedium(color: Colors.white, weight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_releases.isEmpty)
          _loading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: CenteredLoader(),
                )
              : Panel(
                  child: Text(
                    "No releases loaded",
                    style: AppText.bodyMedium(color: AppColors.textSecondary),
                  ),
                )
        else
          Column(
            spacing: AppSpacing.sm,
            children: [
              for (final release in _releases)
                _ReleaseRow(release: release, protonState: protonState),
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
    );
  }
}

class _InstalledVersionsPanel extends ConsumerWidget {
  const _InstalledVersionsPanel({required this.protonState});

  final ProtonState protonState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (protonState.installedTags.isEmpty) {
      return Panel(
        child: Text(
          "No Proton-GE versions installed yet. Install one below.",
          style: AppText.bodyMedium(color: AppColors.textSecondary),
        ),
      );
    }
    return Column(
      spacing: AppSpacing.xs,
      children: [
        for (final tag in protonState.installedTags)
          ClickableContainer(
            onTap: () => ref.read(protonStateProvider.notifier).setDefault(tag),
            child: Panel(
              selected: protonState.defaultVersion == tag,
              child: Row(
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
                  if (protonState.defaultVersion == tag)
                    Text("Default", style: AppText.caption(color: AppColors.primary)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ReleaseRow extends ConsumerWidget {
  const _ReleaseRow({required this.release, required this.protonState});

  final ProtonRelease release;
  final ProtonState protonState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tag = release.tagName();
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
                formatBytes(release.downloadSize().toInt()),
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
                onTap: () => _install(ref),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _install(WidgetRef ref) async {
    final PickedLocation? location = await DirPicker.pick();
    if (location == null) {
      return;
    }
    final path = location.uri!.toFilePath();
    await ref.read(protonStateProvider.notifier).downloadRelease(release, path);
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.task});

  final ProtonTask task;

  @override
  Widget build(BuildContext context) {
    final double? progress = task.total > 0 ? task.transferred / task.total : null;
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
        Text(_statusText(), style: AppText.caption(color: AppColors.textSecondary)),
      ],
    );
  }

  String _statusText() {
    switch (task.stage) {
      case "extracting":
        return "Extracting…";
      case "downloaded":
        return "Finishing…";
      case "downloading":
      default:
        return "Downloading… ${formatBytes(task.transferred)}"
            "/${formatBytes(task.total)}";
    }
  }
}
