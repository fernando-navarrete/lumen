import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gogdl2_flutter/components/panel.dart';
import 'package:gogdl2_flutter/state/downloads_state.dart';
import 'package:gogdl2_flutter/state/gog_state.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';
import 'package:gogdl2_flutter/theme/app_dimens.dart';
import 'package:gogdl2_flutter/theme/text_styles.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsState = ref.watch(downloadsStateProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Downloads", style: AppText.sectionLabel),
          const SizedBox(height: AppSpacing.sm),
          _EmptyState(message: "No active downloads"),
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
    final double? progress = task.totalFiles > 0
        ? task.verifiedFiles / task.totalFiles
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
          Text(_statusText(task), style: AppText.caption(color: _statusColor(task))),
        ],
      ),
    );
  }

  String _statusText(ActivityTask task) {
    switch (task.status) {
      case TaskStatus.running:
        return "Verifying files… ${task.verifiedFiles}/${task.totalFiles}";
      case TaskStatus.completed:
        return task.errorFiles.isEmpty
            ? "Completed"
            : "Completed — ${task.errorFiles.length} file(s) failed checksum";
      case TaskStatus.failed:
        return "Verification failed";
    }
  }

  Color _statusColor(ActivityTask task) {
    if (task.status == TaskStatus.failed ||
        (task.status == TaskStatus.completed && task.errorFiles.isNotEmpty)) {
      return AppColors.error;
    }
    return AppColors.textSecondary;
  }
}
