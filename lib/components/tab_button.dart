import 'package:flutter/material.dart';
import 'package:gogdl2_flutter/common/clickable_container.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';
import 'package:gogdl2_flutter/theme/app_dimens.dart';
import 'package:gogdl2_flutter/theme/text_styles.dart';

enum TabButtonStyle {
  /// Filled rounded pill when selected (nav bar).
  pill,

  /// Accent bottom border when selected (in-page tabs).
  underline,
}

/// A selectable labeled tab used by the nav bar and the game detail tabs.
class TabButton extends StatelessWidget {
  const TabButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.style = TabButtonStyle.pill,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final TabButtonStyle style;

  @override
  Widget build(BuildContext context) {
    return ClickableContainer(
      onTap: onTap,
      child: switch (style) {
        TabButtonStyle.pill => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: isSelected
              ? BoxDecoration(
                  color: AppColors.border12,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                )
              : null,
          child: Text(
            label,
            style: AppText.onest(
              size: 13,
              weight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
        TabButtonStyle.underline => Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            border: isSelected
                ? const Border(
                    bottom: BorderSide(color: AppColors.primary, width: 2.0),
                  )
                : null,
          ),
          child: Text(
            label,
            style: AppText.bodyMedium(
              weight: isSelected ? FontWeight.w500 : FontWeight.w400,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      },
    );
  }
}
