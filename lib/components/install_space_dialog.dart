import 'package:flutter/material.dart';
import 'package:lumen/common/format.dart';
import 'package:lumen/models/install_size.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

/// How an install fits the folder's free space.
enum InstallSpaceVerdict {
  /// The size or the free space couldn't be read; don't block.
  unknown,
  fits,

  /// Fits, but less than 5% of the install size would remain free.
  tight,

  /// `diskBytes > free` — the same test gogdl-lib's own pre-flight makes.
  insufficient,
}

InstallSpaceVerdict installSpaceVerdict(InstallSize? size, int? free) {
  if (size == null || free == null) return InstallSpaceVerdict.unknown;
  if (size.diskBytes > free) return InstallSpaceVerdict.insufficient;
  if (free < size.diskBytes * 1.05) return InstallSpaceVerdict.tight;
  return InstallSpaceVerdict.fits;
}

enum InstallSpaceChoice { install, chooseAnother }

/// Shows what installing [gameName] into [path] takes. Returns the choice,
/// or null if the dialog was dismissed. An insufficient fit offers no
/// Install.
Future<InstallSpaceChoice?> showInstallSpaceDialog(
  BuildContext context, {
  required String gameName,
  required String path,
  required InstallSize? size,
  required int? free,
}) => showDialog<InstallSpaceChoice>(
  context: context,
  builder: (_) => _InstallSpaceDialog(
    gameName: gameName,
    path: path,
    size: size,
    free: free,
  ),
);

class _InstallSpaceDialog extends StatelessWidget {
  const _InstallSpaceDialog({
    required this.gameName,
    required this.path,
    required this.size,
    required this.free,
  });

  final String gameName;
  final String path;
  final InstallSize? size;
  final int? free;

  @override
  Widget build(BuildContext context) {
    final verdict = installSpaceVerdict(size, free);
    final blocked = verdict == InstallSpaceVerdict.insufficient;
    final parts = [
      if (size != null) 'Download ${formatBytes(size!.downloadBytes)}',
      if (size != null) 'Needs ${formatBytes(size!.diskBytes)} on disk',
      if (free != null) '${formatBytes(free!)} free in $path',
    ];
    final (String? note, Color noteColor) = switch (verdict) {
      InstallSpaceVerdict.insufficient => (
        'Not enough space: needs ${formatBytes(size!.diskBytes)}, '
            'only ${formatBytes(free!)} free',
        AppColors.error,
      ),
      InstallSpaceVerdict.tight => (
        'Less than 5% of the install size would remain free.',
        AppColors.warning,
      ),
      InstallSpaceVerdict.unknown => (
        size == null
            ? "Couldn't determine the download size"
            : "Couldn't determine the free space",
        AppColors.warning,
      ),
      InstallSpaceVerdict.fits => (null, AppColors.textSecondary),
    };

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
              Text('Install $gameName?', style: AppText.sectionLabel),
              const SizedBox(height: AppSpacing.sm),
              if (parts.isNotEmpty)
                Text(
                  parts.join(' · '),
                  style: AppText.meta(color: AppColors.textSecondary),
                ),
              if (note != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(note, style: AppText.meta(color: noteColor)),
              ],
              const SizedBox(height: AppSpacing.md),
              Wrap(
                alignment: WrapAlignment.end,
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
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(InstallSpaceChoice.chooseAnother),
                    child: Text(
                      'Choose another folder',
                      style: AppText.button(color: Colors.white),
                    ),
                  ),
                  if (!blocked)
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pop(InstallSpaceChoice.install),
                      child: Text(
                        'Install',
                        style: AppText.button(color: AppColors.primary),
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
