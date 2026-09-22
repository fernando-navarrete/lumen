import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/format.dart';
import 'package:lumen/common/save_status.dart';
import 'package:lumen/components/gradient_progress_bar.dart';
import 'package:lumen/components/primary_button.dart';
import 'package:lumen/components/section_card.dart';
import 'package:lumen/state/downloads_state.dart' show TaskStatus;
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/saves_state.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

/// Per-game cloud save tab: lets the user pull every remote save file down
/// or push every local one up, with live progress inline. There's no
/// automatic merge, so Download and Upload are separate, explicit actions.
/// The same task also shows as a card in the Downloads tab's "Cloud Saves"
/// section (see [SavesNotifier]).
///
/// Whether the game supports cloud saves isn't known up front — the bridge
/// only reports it when a sync runs, as a failure or a zero-file sync.
class SavesTab extends ConsumerWidget {
  const SavesTab({super.key, required this.gameId});

  final int gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesState = ref.watch(gamesStateProvider);
    final ready =
        gamesState.getInstallPath(gameId) != null &&
        gamesState.getSelectedBuild(gameId) != null;
    // Watch the whole state, not a `select`: SavesNotifier mutates the same
    // SaveTask instance in place, so identity-based `select` never sees the
    // change. Revert to `select` once tasks are immutable (v1.1.0, GAPS 4.1).
    final task = ref.watch(savesStateProvider).taskFor(gameId);
    final syncing = task?.status == TaskStatus.running;
    final notifier = ref.read(savesStateProvider.notifier);

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
                    "Download or upload this game's GOG cloud saves.",
                    style: AppText.bodyMedium(
                      color: Colors.white,
                      weight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    ready
                        ? "There's no automatic merge — the two directions are "
                              "explicit, and nothing is ever deleted."
                        : "Install the game to sync its saves",
                    style: AppText.cardDesc(),
                  ),
                ],
              ),
            ),
            Row(
              spacing: AppSpacing.sm,
              children: [
                PrimaryButton.icon(
                  icon: Icons.cloud_download,
                  label: "Download",
                  glowing: true,
                  enabled: ready && !syncing,
                  onTap: () => notifier.downloadSaves(gameId),
                ),
                PrimaryButton.icon(
                  icon: Icons.cloud_upload,
                  label: "Upload",
                  glowing: false,
                  enabled: ready && !syncing,
                  onTap: () => notifier.uploadSaves(gameId),
                ),
              ],
            ),
            if (task != null) _SyncProgress(task: task),
          ],
        ),
      ),
    );
  }
}

/// Live status line, bar and current-file detail for one [SaveTask]. The bar
/// is indeterminate until the bridge's first `Started` event arrives.
class _SyncProgress extends StatelessWidget {
  const _SyncProgress({required this.task});

  final SaveTask task;

  @override
  Widget build(BuildContext context) {
    final failed = task.status == TaskStatus.failed;
    final progress = task.progress;
    final file = task.currentFile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xs,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                saveStatusText(task),
                style: AppText.caption(
                  color: failed ? AppColors.error : AppColors.textSecondary,
                ),
              ),
            ),
            if (progress != null)
              Text(
                "${(progress * 100).round()}%",
                style: AppText.onest(
                  size: 13,
                  weight: FontWeight.w600,
                  color: failed ? AppColors.error : AppColors.primaryLight,
                ),
              ),
          ],
        ),
        if (failed)
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress ?? 0,
              minHeight: 6,
              backgroundColor: AppColors.progressTrack,
              valueColor: const AlwaysStoppedAnimation(AppColors.error),
            ),
          )
        else if (progress != null)
          GradientProgressBar(value: progress)
        else if (task.status == TaskStatus.running)
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: const LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: AppColors.progressTrack,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        if (file != null)
          Text(
            "$file · ${formatBytes(task.fileTransferred)}"
            " / ${formatBytes(task.fileTotal)}",
            style: AppText.caption(color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}
