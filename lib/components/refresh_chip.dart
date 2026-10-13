import 'package:flutter/material.dart';
import 'package:lumen/common/clickable_container.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

/// Quiet "Refresh" chip. While [busy] it shows a spinner and ignores taps.
class RefreshChip extends StatelessWidget {
  const RefreshChip({super.key, required this.onTap, this.busy = false});

  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return ClickableContainer(
      onTap: busy ? () {} : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.fill06,
          border: Border.all(color: AppColors.border10),
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            if (busy)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.text80,
                ),
              )
            else
              const Icon(Icons.refresh, size: 14, color: AppColors.text80),
            Text(
              'Refresh',
              style: AppText.onest(
                size: 12.5,
                weight: FontWeight.w600,
                color: AppColors.text80,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
