import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/format.dart';
import 'package:lumen/components/async_cover_image.dart';
import 'package:lumen/components/gradient_progress_bar.dart';
import 'package:lumen/components/primary_button.dart';
import 'package:lumen/state/downloads_state.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/state/saves_state.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_decorations.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsState = ref.watch(downloadsStateProvider);
    final savesState = ref.watch(savesStateProvider);
    final saveTasks = savesState.tasks.values.toList();

    // Active = running or failed; completed installs move to the
    // "recently installed" list below.
    bool isActive(ActivityTask task) => task.status != TaskStatus.completed;

    final activeTransfers = [
      ...downloadsState.downloadTasks.where(isActive),
      ...downloadsState.repairTasks.where(isActive),
    ];
    final activeVerifications = downloadsState.verificationTasks
        .where(isActive)
        .toList();
    final completed = downloadsState.tasks.values
        .where((task) => task.status == TaskStatus.completed)
        .toList();

    final int activeCount =
        activeTransfers.length +
        activeVerifications.length +
        saveTasks.where((task) => task.status == TaskStatus.running).length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Downloads", style: AppText.pageTitle),
              const SizedBox(height: 6),
              Text(
                "$activeCount active · ${completed.length} completed",
                style: AppText.onest(
                  size: 13.5,
                  weight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text("ACTIVE", style: AppText.microLabel),
              const SizedBox(height: AppSpacing.sm),
              if (activeTransfers.isEmpty)
                const _EmptyState(message: "No active downloads")
              else
                Column(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final task in activeTransfers)
                      _ActiveTaskCard(
                        gameId: task.gameId,
                        progress: task.progress,
                        statusText: task.kind == TaskKind.download
                            ? _downloadStatusText(task)
                            : _repairStatusText(task),
                        failed: _hasErrors(task),
                      ),
                  ],
                ),
              const SizedBox(height: AppSpacing.xl),
              Text("VERIFICATIONS", style: AppText.microLabel),
              const SizedBox(height: AppSpacing.sm),
              if (activeVerifications.isEmpty)
                const _EmptyState(message: "No active verifications")
              else
                Column(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final task in activeVerifications)
                      _ActiveTaskCard(
                        gameId: task.gameId,
                        progress: task.progress,
                        statusText: _verificationStatusText(task),
                        failed: _hasErrors(task),
                        trailing: task.status == TaskStatus.failed
                            ? PrimaryButton.icon(
                                icon: Icons.build,
                                label: "Repair",
                                glowing: false,
                                onTap: () => ref
                                    .read(downloadsStateProvider.notifier)
                                    .startRepair(task.gameId),
                              )
                            : null,
                      ),
                  ],
                ),
              const SizedBox(height: AppSpacing.xl),
              Text("RECENTLY INSTALLED", style: AppText.microLabel),
              const SizedBox(height: AppSpacing.sm),
              if (completed.isEmpty)
                const _EmptyState(message: "Nothing installed this session")
              else
                Column(
                  spacing: AppSpacing.xs,
                  children: [
                    for (final task in completed)
                      _RecentInstallRow(
                        gameId: task.gameId,
                        statusText: _completedStatusText(task),
                        failed: _hasErrors(task),
                      ),
                  ],
                ),
              const SizedBox(height: AppSpacing.xl),
              Text("CLOUD SAVES", style: AppText.microLabel),
              const SizedBox(height: AppSpacing.sm),
              if (saveTasks.isEmpty)
                const _EmptyState(message: "No active save syncs")
              else
                Column(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final task in saveTasks)
                      _ActiveTaskCard(
                        gameId: task.gameId,
                        progress: task.filesTotal > 0
                            ? task.filesProcessed / task.filesTotal
                            : null,
                        statusText: _saveStatusText(task),
                        failed:
                            task.status == TaskStatus.failed ||
                            task.errorFiles.isNotEmpty,
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

bool _hasErrors(ActivityTask task) =>
    task.status == TaskStatus.failed ||
    (task.status == TaskStatus.completed && task.errorFiles.isNotEmpty);

String _downloadStatusText(ActivityTask task) {
  switch (task.status) {
    case TaskStatus.running:
      switch (task.stage) {
        case "checkingFiles":
          return "Checking existing files… ${task.processedFiles}"
              " of ${task.totalFiles}";
        case "allocating":
          return "Allocating disk space… ${task.processedFiles}"
              " of ${task.totalFiles} files";
        case "downloading":
          return "Downloading… ${formatBytes(task.downloadedBytes)}"
              " of ${formatBytes(task.totalBytes)}";
        case "finished":
          return "Finishing…";
        default:
          return "Preparing…";
      }
    case TaskStatus.completed:
      return "Downloaded";
    case TaskStatus.failed:
      return task.errorFiles.isEmpty
          ? "Download failed"
          : "Download failed — couldn't create"
                " ${task.errorFiles.length} file(s)";
  }
}

String _repairStatusText(ActivityTask task) {
  switch (task.status) {
    case TaskStatus.running:
      switch (task.stage) {
        case "fetchingFiles":
          return "Fetching files…";
        case "verifyingFiles":
          return "Verifying files…";
        case "allocating":
          return "Allocating disk space…";
        case "verifyingChunks":
          return "Verifying chunks…";
        case "downloading":
          return "Repairing… ${formatBytes(task.downloadedBytes)}"
              " of ${formatBytes(task.totalBytes)}";
        default:
          return "Repairing…";
      }
    case TaskStatus.completed:
      return task.errorFiles.isEmpty
          ? "Repaired"
          : "Repaired — ${task.errorFiles.length} file(s) still failing";
    case TaskStatus.failed:
      return "Repair failed";
  }
}

String _verificationStatusText(ActivityTask task) {
  switch (task.status) {
    case TaskStatus.running:
      switch (task.stage) {
        case "verifying":
          return "Verifying… ${formatBytes(task.downloadedBytes)}"
              " of ${formatBytes(task.totalBytes)}";
        default:
          return "Fetching file list…";
      }
    case TaskStatus.completed:
      return "Verified";
    case TaskStatus.failed:
      return task.verifyFailures.isEmpty
          ? "Verification failed"
          : "Damaged — ${_verifyFailureSummary(task)}";
  }
}

/// Joins the non-zero per-reason failure counts from a failed verification,
/// e.g. "2 missing, 1 corrupt (312 chunks to re-download)".
String _verifyFailureSummary(ActivityTask task) {
  final parts = [
    if (task.verifyFailureCount(VerifyFailure.missing) > 0)
      "${task.verifyFailureCount(VerifyFailure.missing)} missing",
    if (task.verifyFailureCount(VerifyFailure.corrupt) > 0)
      "${task.verifyFailureCount(VerifyFailure.corrupt)} corrupt",
    if (task.verifyFailureCount(VerifyFailure.unreadable) > 0)
      "${task.verifyFailureCount(VerifyFailure.unreadable)} unreadable",
  ];
  final summary = parts.join(", ");
  final chunks = task.chunksToRedownload;
  return chunks != null && chunks > 0
      ? "$summary ($chunks chunk(s) to re-download)"
      : summary;
}

String _completedStatusText(ActivityTask task) {
  final String base = switch (task.kind) {
    TaskKind.download => "Downloaded",
    TaskKind.repair => "Repaired",
    TaskKind.verification => "Verified",
  };
  return task.errorFiles.isEmpty
      ? base
      : "$base — ${task.errorFiles.length} file(s) failed";
}

String _saveStatusText(SaveTask task) {
  final verb = task.direction == SaveDirection.download
      ? "Downloading"
      : "Uploading";
  final doneVerb = task.direction == SaveDirection.download
      ? "downloaded"
      : "uploaded";
  switch (task.status) {
    case TaskStatus.running:
      return "$verb saves… ${task.filesProcessed}/${task.filesTotal} files"
          " (${formatBytes(task.transferred)}/${formatBytes(task.total)})";
    case TaskStatus.completed:
      return task.errorFiles.isEmpty
          ? "Saves $doneVerb"
          : "Saves $doneVerb — ${task.errorFiles.length} file(s) failed";
    case TaskStatus.failed:
      return task.direction == SaveDirection.download
          ? "Save download failed"
          : "Save upload failed";
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    decoration: AppDecorations.glassRow(),
    child: Text(
      message,
      style: AppText.bodyMedium(color: AppColors.textSecondary),
    ),
  );
}

/// Glass card for one in-flight task: cover thumb, name, percentage,
/// gradient progress bar and a status line.
class _ActiveTaskCard extends ConsumerWidget {
  const _ActiveTaskCard({
    required this.gameId,
    required this.progress,
    required this.statusText,
    required this.failed,
    this.trailing,
  });

  final int gameId;
  final double? progress;
  final String statusText;
  final bool failed;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gogState = ref.watch(gogStateProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppDecorations.glassRow(),
      child: Row(
        spacing: AppSpacing.md,
        children: [
          SizedBox(
            width: 48,
            height: 64,
            child: AsyncCoverImage(
              imageUrl: gogState.getGameBoxartLink(gameId),
              borderRadius: AppRadii.chipSmall,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xs,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FutureBuilder<String?>(
                        future: gogState.getGameName(gameId),
                        builder: (context, snapshot) => Text(
                          snapshot.data ?? "Loading...",
                          style: AppText.cardTitle(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (progress != null)
                      Text(
                        "${(progress! * 100).round()}%",
                        style: AppText.onest(
                          size: 13,
                          weight: FontWeight.w600,
                          color: failed
                              ? AppColors.error
                              : AppColors.primaryLight,
                        ),
                      ),
                  ],
                ),
                failed
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: progress ?? 0,
                          minHeight: 6,
                          backgroundColor: AppColors.progressTrack,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.error,
                          ),
                        ),
                      )
                    : progress != null
                    ? GradientProgressBar(value: progress!)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: const LinearProgressIndicator(
                          minHeight: 6,
                          backgroundColor: AppColors.progressTrack,
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                Text(
                  statusText,
                  style: AppText.caption(
                    color: failed ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Quiet row for a task that finished this session.
class _RecentInstallRow extends ConsumerWidget {
  const _RecentInstallRow({
    required this.gameId,
    required this.statusText,
    required this.failed,
  });

  final int gameId;
  final String statusText;
  final bool failed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gogState = ref.watch(gogStateProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.fill04,
        border: Border.all(color: AppColors.border07),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        spacing: 14,
        children: [
          SizedBox(
            width: 34,
            height: 46,
            child: AsyncCoverImage(
              imageUrl: gogState.getGameBoxartLink(gameId),
              borderRadius: AppRadii.chipSmall,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                FutureBuilder<String?>(
                  future: gogState.getGameName(gameId),
                  builder: (context, snapshot) => Text(
                    snapshot.data ?? "Loading...",
                    style: AppText.bodyMedium(
                      color: Colors.white,
                      weight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(statusText, style: AppText.caption(color: AppColors.text40)),
              ],
            ),
          ),
          Text(
            failed ? "⚠ Check files" : "✓ Installed",
            style: AppText.chip(
              color: failed ? AppColors.error : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
