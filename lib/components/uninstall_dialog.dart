import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen/common/directory_size.dart';
import 'package:lumen/common/format.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/state/uninstall.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

/// What the user chose in the uninstall dialog.
typedef UninstallChoice = ({bool deleteFiles, bool deletePrefix});

/// Confirms uninstalling [gameId] and runs [Uninstaller.uninstallGame],
/// showing a snackbar if it refuses or fails. [onOpenSaves] is the dialog's
/// "Open Saves tab" link (closing the dialog first); [onUninstalled] runs
/// after a successful uninstall.
Future<void> confirmUninstall(
  BuildContext context,
  WidgetRef ref,
  int gameId, {
  VoidCallback? onOpenSaves,
  VoidCallback? onUninstalled,
}) async {
  final config = ref.read(gamesStateProvider).games[gameId];
  final path = config?.installPath;
  final name = await ref.read(gogStateProvider).getGameName(gameId);
  if (!context.mounted) return;

  final result = await showDialog<Object?>(
    context: context,
    builder: (_) => _UninstallDialog(
      gameName: name ?? 'this game',
      path: path,
      ownsDir: config?.ownsInstallDir ?? false,
    ),
  );
  if (result == _openSaves) {
    onOpenSaves?.call();
    return;
  }
  if (result is! UninstallChoice) return;

  try {
    await ref
        .read(uninstallerProvider)
        .uninstallGame(
          gameId,
          deleteFiles: result.deleteFiles,
          deletePrefix: result.deletePrefix,
        );
    onUninstalled?.call();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not uninstall: $e')));
    }
  }
}

const _openSaves = Object();

class _UninstallDialog extends StatefulWidget {
  const _UninstallDialog({
    required this.gameName,
    required this.path,
    required this.ownsDir,
  });

  final String gameName;
  final String? path;
  final bool ownsDir;

  @override
  State<_UninstallDialog> createState() => _UninstallDialogState();
}

class _UninstallDialogState extends State<_UninstallDialog> {
  late bool _deleteFiles = widget.ownsDir;
  bool _deletePrefix = false;
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

  Widget _checkbox(String label, bool value, ValueChanged<bool> onChanged) =>
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        title: Text(label, style: AppText.meta(color: Colors.white)),
      );

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
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Uninstall ${widget.gameName}?',
                  style: AppText.sectionLabel,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (widget.path != null)
                  Text(
                    'Installed in ${widget.path}$sizeText.',
                    style: AppText.meta(color: AppColors.textSecondary),
                  ),
                _checkbox(
                  'Delete game files',
                  _deleteFiles,
                  (v) => setState(() => _deleteFiles = v),
                ),
                if (!widget.ownsDir && _deleteFiles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      "Lumen didn't create this folder, so it may hold other "
                      'files. Everything in ${widget.path} will be deleted.',
                      style: AppText.meta(color: AppColors.warning),
                    ),
                  ),
                _checkbox(
                  'Also delete the Wine prefix (saves stored in the prefix '
                  'will be lost)',
                  _deletePrefix,
                  (v) => setState(() => _deletePrefix = v),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  "The game's settings (launch arguments, environment "
                  'variables, wrapper and Proton version) are reset too.',
                  style: AppText.meta(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'If the game has cloud saves, upload them first.',
                  style: AppText.meta(color: AppColors.textSecondary),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(_openSaves),
                    child: Text(
                      'Open Saves tab',
                      style: AppText.button(color: AppColors.primary),
                    ),
                  ),
                ),
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
                      onPressed: () => Navigator.of(context).pop((
                        deleteFiles: _deleteFiles,
                        deletePrefix: _deletePrefix,
                      )),
                      child: Text(
                        'Uninstall',
                        style: AppText.button(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
