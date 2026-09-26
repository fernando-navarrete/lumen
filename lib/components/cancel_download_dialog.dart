import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/directory_size.dart';
import 'package:lumen/common/format.dart';
import 'package:lumen/state/downloads_state.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

/// Confirms cancelling [gameId]'s download (running or paused) and runs
/// [DownloadsNotifier.cancelDownload], showing a snackbar if deleting the
/// partial files fails. Shared by the Downloads page and `GameActionButtons`.
Future<void> confirmCancelDownload(
  BuildContext context,
  WidgetRef ref,
  int gameId,
) async {
  final games = ref.read(gamesStateProvider);
  final path =
      games.getPendingInstallPath(gameId) ??
      ref.read(downloadsStateProvider).tasks[gameId]?.path;
  final canDelete = games.games[gameId]?.ownsPendingInstallDir ?? false;
  final name = await ref.read(gogStateProvider).getGameName(gameId);
  if (!context.mounted) return;

  final deleteFiles = await showCancelDownloadDialog(
    context,
    gameName: name ?? 'this game',
    path: path,
    canDelete: canDelete,
  );
  if (deleteFiles == null) return;

  try {
    await ref
        .read(downloadsStateProvider.notifier)
        .cancelDownload(gameId, deleteFiles: deleteFiles);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete files: $e')));
    }
  }
}

/// Returns whether to delete the partial files, or null if the dialog was
/// dismissed. When [canDelete] is false (the folder wasn't empty when the
/// download started) "Keep files" is forced on.
Future<bool?> showCancelDownloadDialog(
  BuildContext context, {
  required String gameName,
  required String? path,
  required bool canDelete,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _CancelDownloadDialog(
    gameName: gameName,
    path: path,
    canDelete: canDelete,
  ),
);

class _CancelDownloadDialog extends StatefulWidget {
  const _CancelDownloadDialog({
    required this.gameName,
    required this.path,
    required this.canDelete,
  });

  final String gameName;
  final String? path;
  final bool canDelete;

  @override
  State<_CancelDownloadDialog> createState() => _CancelDownloadDialogState();
}

class _CancelDownloadDialogState extends State<_CancelDownloadDialog> {
  late bool _keepFiles = !widget.canDelete;
  bool _sizeLoaded = false;
  int? _size;

  @override
  void initState() {
    super.initState();
    final path = widget.path;
    if (path == null) {
      _sizeLoaded = true;
      return;
    }
    directorySize(path).then((size) {
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
        ? ' (…)'
        : _size == null
        ? ''
        : ' (${formatBytes(_size!)})';
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
              Text(
                'Cancel installing ${widget.gameName}?',
                style: AppText.sectionLabel,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (widget.path != null)
                Text(
                  'Downloaded files$sizeText in ${widget.path}'
                  '${_keepFiles ? ' will be kept.' : ' will be deleted.'}',
                  style: AppText.meta(color: AppColors.textSecondary),
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _keepFiles,
                onChanged: widget.canDelete
                    ? (v) => setState(() => _keepFiles = v ?? false)
                    : null,
                title: Text(
                  'Keep files',
                  style: AppText.meta(color: Colors.white),
                ),
              ),
              if (!widget.canDelete)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    "This folder wasn't empty when the download started, so "
                    "Lumen won't delete it. Remove the downloaded files by "
                    'hand if you no longer want them.',
                    style: AppText.meta(color: AppColors.warning),
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
                      'Back',
                      style: AppText.button(color: AppColors.textSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(!_keepFiles),
                    child: Text(
                      'Cancel install',
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
