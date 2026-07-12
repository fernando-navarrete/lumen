import 'package:flutter/material.dart';
import 'package:lumen/theme/app_colors.dart';

/// Rounded progress bar with the teal design gradient as its fill.
/// [value] is clamped to 0..1; pass null-safe values only.
class GradientProgressBar extends StatelessWidget {
  const GradientProgressBar({super.key, required this.value, this.height = 6});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: height,
        color: AppColors.progressTrack,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
