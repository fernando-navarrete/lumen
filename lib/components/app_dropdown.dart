import 'package:flutter/material.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_decorations.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

/// One selectable option in an [AppDropdown].
class AppDropdownEntry<T> {
  const AppDropdownEntry({required this.value, required this.label});

  final T value;
  final String label;
}

/// Themed replacement for a raw [DropdownButton]: a bordered panel matching
/// [AppDecorations.panel] with `AppText`-styled entries. Used anywhere a
/// screen-filling list of choices (e.g. installed Proton versions) should
/// collapse into a compact selector instead.
///
/// [value] may be `null` to represent "nothing selected" (or, when [entries]
/// itself contains a `null`-valued entry, an explicit "use default" choice).
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.value,
    required this.entries,
    required this.onChanged,
    this.placeholder,
  });

  final T? value;
  final List<AppDropdownEntry<T>> entries;

  /// Null disables the dropdown (rendered dimmed, non-interactive).
  final ValueChanged<T?>? onChanged;

  /// Shown when there are no [entries] to choose from.
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null && entries.isNotEmpty;
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: AppDecorations.input,
      child: entries.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                placeholder ?? "No options available",
                style: AppText.bodyMedium(color: AppColors.textSecondary),
              ),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                dropdownColor: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.control),
                style: AppText.bodyMedium(color: Colors.white, weight: FontWeight.w500),
                onChanged: enabled ? onChanged : null,
                items: [
                  for (final entry in entries)
                    DropdownMenuItem<T>(
                      value: entry.value,
                      child: Text(
                        entry.label,
                        style: AppText.bodyMedium(color: Colors.white, weight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
            ),
    );
    return enabled || entries.isEmpty ? content : Opacity(opacity: 0.5, child: content);
  }
}
