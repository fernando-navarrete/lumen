import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/format.dart';
import 'package:lumen/components/panel.dart';
import 'package:lumen/components/primary_button.dart';
import 'package:lumen/state/downloads_state.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/state/saves_state.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsState = ref.watch(downloadsStateProvider);
    final savesState = ref.watch(savesStateProvider);
    final saveTasks = savesState.tasks.values.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Downloads", style: AppText.sectionLabel),
          const SizedBox(height: AppSpacing.sm),
          if (downloadsState.downloadTasks.isEmpty &&
              downloadsState.repairTasks.isEmpty)
            _EmptyState(message: "No active downloads")
          else
            Column(
              spacing: AppSpacing.sm,
              children: [
                for (final task in downloadsState.downloadTasks)
                  _DownloadTaskCard(task: task),
                for (final task in downloadsState.repairTasks)
                  _RepairTaskCard(task: task),
              ],
            ),
          const SizedBox(height: AppSpacing.xl),
          Text("Verifications", style: AppText.sectionLabel),
          const SizedBox(height: AppSpacing.sm),
          if (downloadsState.verificationTasks.isEmpty)
            _EmptyState(message: "No active verifications")
          else
            Column(
              spacing: AppSpacing.sm,
              children: [
                for (final task in downloadsState.verificationTasks)
                  _VerificationTaskCard(task: task),
              ],
            ),
          const SizedBox(height: AppSpacing.xl),
          Text("Cloud Saves", style: AppText.sectionLabel),
          const SizedBox(height: AppSpacing.sm),
          if (saveTasks.isEmpty)
            _EmptyState(message: "No active save syncs")
          else
            Column(
              spacing: AppSpacing.sm,
              children: [
                for (final task in saveTasks) _SaveTaskCard(task: task),
              ],
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Panel(
    child: Text(
      message,
      style: AppText.bodyMedium(color: AppColors.textSecondary),
    ),
  );
}

class _VerificationTaskCard extends ConsumerWidget {
  const _VerificationTaskCard({required this.task});

  final ActivityTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gogState = ref.watch(gogStateProvider);
    final double? progress = task.totalChunks > 0
        ? task.verifiedChunks / task.totalChunks
        : null;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xs,
        children: [
          FutureBuilder<String?>(
            future: gogState.getGameName(task.gameId),
            builder: (context, snapshot) => Text(
              snapshot.data ?? "Loading...",
              style: AppText.bodyMedium(
                color: Colors.white,
                weight: FontWeight.w600,
              ),
            ),
          ),
          Row(
            spacing: AppSpacing.sm,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.control),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppColors.border08,
                    valueColor: AlwaysStoppedAnimation(
                      task.status == TaskStatus.failed
                          ? AppColors.error
                          : AppColors.primary,
                    ),
                  ),
                ),
              ),
              if (task.status == TaskStatus.failed)
                PrimaryButton.icon(
                  icon: Icons.build,
                  label: "Repair",
                  glowing: false,
                  onTap: () => ref
                      .read(downloadsStateProvider.notifier)
                      .startRepair(task.gameId),
                ),
            ],
          ),
          Text(
            _statusText(task),
            style: AppText.caption(color: _statusColor(task)),
          ),
        ],
      ),
    );
  }

  String _statusText(ActivityTask task) {
    switch (task.status) {
      case TaskStatus.running:
        return "Verifying chunks… ${task.verifiedChunks}/${task.totalChunks}";
      case TaskStatus.completed:
        return task.errorChunks.isEmpty
            ? "Completed"
            : "Completed — ${task.errorChunks.length} chunk(s) failed checksum";
      case TaskStatus.failed:
        return "Verification failed";
    }
  }

  Color _statusColor(ActivityTask task) {
    if (task.status == TaskStatus.failed ||
        (task.status == TaskStatus.completed && task.errorChunks.isNotEmpty)) {
      return AppColors.error;
    }
    return AppColors.textSecondary;
  }
}

class _DownloadTaskCard extends ConsumerWidget {
  const _DownloadTaskCard({required this.task});

  final ActivityTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gogState = ref.watch(gogStateProvider);
    final double? progress = task.totalBytes > 0
        ? task.downloadedBytes / task.totalBytes
        : null;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xs,
        children: [
          FutureBuilder<String?>(
            future: gogState.getGameName(task.gameId),
            builder: (context, snapshot) => Text(
              snapshot.data ?? "Loading...",
              style: AppText.bodyMedium(
                color: Colors.white,
                weight: FontWeight.w600,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.control),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.border08,
              valueColor: AlwaysStoppedAnimation(
                task.status == TaskStatus.failed
                    ? AppColors.error
                    : AppColors.primary,
              ),
            ),
          ),
          Text(
            _statusText(task),
            style: AppText.caption(color: _statusColor(task)),
          ),
        ],
      ),
    );
  }

  String _statusText(ActivityTask task) {
    switch (task.status) {
      case TaskStatus.running:
        switch (task.stage) {
          case "fetchingFiles":
            return "Fetching files…";
          case "allocating":
            return "Allocating disk space…";
          case "downloading":
            return "Downloading… ${formatBytes(task.downloadedBytes)}"
                "/${formatBytes(task.totalBytes)}";
          default:
            return "Downloading…";
        }
      case TaskStatus.completed:
        return task.errorChunks.isEmpty
            ? "Downloaded"
            : "Downloaded — ${task.errorChunks.length} file(s) failed";
      case TaskStatus.failed:
        return "Download failed";
    }
  }

  Color _statusColor(ActivityTask task) {
    if (task.status == TaskStatus.failed ||
        (task.status == TaskStatus.completed && task.errorChunks.isNotEmpty)) {
      return AppColors.error;
    }
    return AppColors.textSecondary;
  }
}

class _RepairTaskCard extends ConsumerWidget {
  const _RepairTaskCard({required this.task});

  final ActivityTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gogState = ref.watch(gogStateProvider);
    final double? progress = task.totalBytes > 0
        ? task.downloadedBytes / task.totalBytes
        : null;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xs,
        children: [
          FutureBuilder<String?>(
            future: gogState.getGameName(task.gameId),
            builder: (context, snapshot) => Text(
              snapshot.data ?? "Loading...",
              style: AppText.bodyMedium(
                color: Colors.white,
                weight: FontWeight.w600,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.control),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.border08,
              valueColor: AlwaysStoppedAnimation(
                task.status == TaskStatus.failed
                    ? AppColors.error
                    : AppColors.primary,
              ),
            ),
          ),
          Text(
            _statusText(task),
            style: AppText.caption(color: _statusColor(task)),
          ),
        ],
      ),
    );
  }

  String _statusText(ActivityTask task) {
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
            return "Downloading… ${formatBytes(task.downloadedBytes)}"
                "/${formatBytes(task.totalBytes)}";
          default:
            return "Repairing…";
        }
      case TaskStatus.completed:
        return task.errorChunks.isEmpty
            ? "Repaired"
            : "Repaired — ${task.errorChunks.length} file(s) still failing";
      case TaskStatus.failed:
        return "Repair failed";
    }
  }

  Color _statusColor(ActivityTask task) {
    if (task.status == TaskStatus.failed ||
        (task.status == TaskStatus.completed && task.errorChunks.isNotEmpty)) {
      return AppColors.error;
    }
    return AppColors.textSecondary;
  }
}

class _SaveTaskCard extends ConsumerWidget {
  const _SaveTaskCard({required this.task});

  final SaveTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gogState = ref.watch(gogStateProvider);
    final double? progress = task.filesTotal > 0
        ? task.filesProcessed / task.filesTotal
        : null;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xs,
        children: [
          FutureBuilder<String?>(
            future: gogState.getGameName(task.gameId),
            builder: (context, snapshot) => Text(
              snapshot.data ?? "Loading...",
              style: AppText.bodyMedium(
                color: Colors.white,
                weight: FontWeight.w600,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.control),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.border08,
              valueColor: AlwaysStoppedAnimation(
                task.status == TaskStatus.failed
                    ? AppColors.error
                    : AppColors.primary,
              ),
            ),
          ),
          Text(
            _statusText(task),
            style: AppText.caption(color: _statusColor(task)),
          ),
        ],
      ),
    );
  }

  String _statusText(SaveTask task) {
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

  Color _statusColor(SaveTask task) {
    if (task.status == TaskStatus.failed ||
        (task.status == TaskStatus.completed && task.errorFiles.isNotEmpty)) {
      return AppColors.error;
    }
    return AppColors.textSecondary;
  }
}
