import 'package:flutter/material.dart';
import 'package:lumen/common/clickable_container.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

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
    this.badge,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final TabButtonStyle style;

  /// Optional trailing badge (e.g. active download count on Downloads).
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return ClickableContainer(
      onTap: onTap,
      child: switch (style) {
        TabButtonStyle.pill => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: isSelected
              ? BoxDecoration(
                  color: AppColors.border08,
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.xs,
            children: [
              Text(
                label,
                style: AppText.navPill(
                  weight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
              ?badge,
            ],
          ),
        ),
        TabButtonStyle.underline => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
              weight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      },
    );
  }
}
