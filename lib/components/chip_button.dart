import 'package:flutter/material.dart';
import 'package:lumen/common/clickable_container.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

/// Small filter chip: solid teal when selected, quiet glass otherwise.
class ChipButton extends StatelessWidget {
  const ChipButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClickableContainer(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.fill06,
          borderRadius: BorderRadius.circular(AppRadii.chipSmall),
        ),
        child: Text(
          label,
          style: AppText.chip(
            color: selected ? AppColors.onPrimary : AppColors.text70,
          ),
        ),
      ),
    );
  }
}
