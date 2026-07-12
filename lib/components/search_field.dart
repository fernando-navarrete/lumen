import 'package:flutter/material.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

/// Compact nav-bar search field over a translucent fill.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Search',
    this.width = 240,
  });

  final ValueChanged<String> onChanged;
  final String hint;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.fill06,
        border: Border.all(color: AppColors.border10),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        spacing: AppSpacing.xs,
        children: [
          const Icon(Icons.search, size: 15, color: AppColors.textSecondary),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: AppText.onest(
                size: 13,
                weight: FontWeight.w400,
                color: Colors.white,
              ),
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                hintText: hint,
                hintStyle: AppText.onest(
                  size: 13,
                  weight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
