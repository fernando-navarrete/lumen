import 'package:flutter/material.dart';
import 'package:lumen/components/primary_button.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

/// Shows a modal list of executable paths (relative to a game's install
/// directory, e.g. GOG play tasks and `findExecutables` results) and lets
/// the user pick which one to use. A path with an entry in [labels] (a GOG
/// play task's `GOG: <name>`) shows that label, with the path underneath.
/// [message], when set, is a warning shown under the title (e.g. why the
/// user is being asked). Returns the chosen path, or null if canceled.
Future<String?> showExecutablePicker(
  BuildContext context, {
  required List<String> candidates,
  Map<String, String> labels = const {},
  String title = "Choose executable",
  String confirmLabel = "Select",
  String? message,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ExecutablePickerDialog(
      candidates: candidates,
      labels: labels,
      title: title,
      confirmLabel: confirmLabel,
      message: message,
    ),
  );
}

class _ExecutablePickerDialog extends StatefulWidget {
  const _ExecutablePickerDialog({
    required this.candidates,
    required this.labels,
    required this.title,
    required this.confirmLabel,
    this.message,
  });

  final List<String> candidates;
  final Map<String, String> labels;
  final String title;
  final String confirmLabel;
  final String? message;

  @override
  State<_ExecutablePickerDialog> createState() =>
      _ExecutablePickerDialogState();
}

class _ExecutablePickerDialogState extends State<_ExecutablePickerDialog> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.candidates.isNotEmpty ? widget.candidates.first : null;
  }

  @override
  Widget build(BuildContext context) {
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
                    child: Text(widget.title, style: AppText.sectionLabel),
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
              if (widget.message != null)
                Text(
                  widget.message!,
                  style: AppText.bodyMedium(color: AppColors.warning),
                ),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: SingleChildScrollView(
                  child: RadioGroup<String>(
                    groupValue: _selected,
                    onChanged: (value) => setState(() => _selected = value),
                    child: Column(
                      children: [
                        for (final path in widget.candidates)
                          RadioListTile<String>(
                            value: path,
                            title: Text(
                              widget.labels[path] ?? path,
                              style: AppText.bodyMedium(color: Colors.white),
                            ),
                            subtitle: widget.labels.containsKey(path)
                                ? Text(
                                    path,
                                    style: AppText.code(
                                      color: AppColors.textSecondary,
                                    ),
                                  )
                                : null,
                            activeColor: AppColors.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: AppSpacing.sm,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      "Cancel",
                      style: AppText.button(color: AppColors.textSecondary),
                    ),
                  ),
                  PrimaryButton(
                    enabled: _selected != null,
                    glowing: true,
                    onTap: () => Navigator.of(context).pop(_selected),
                    child: Text(
                      widget.confirmLabel,
                      style: AppText.button(color: Colors.black),
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
