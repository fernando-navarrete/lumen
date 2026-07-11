import 'package:flutter/material.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

/// Circular step number that turns into a check mark once completed.
class StepIndicator extends StatelessWidget {
  const StepIndicator({
    super.key,
    required this.isComplete,
    required this.step,
  });

  final bool isComplete;
  final int step;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: isComplete
            ? null
            : Border.all(color: AppColors.primary, width: 1.0),
        color: isComplete ? AppColors.primary : AppColors.primary.withAlpha(64),
      ),
      child: isComplete
          ? const Icon(Icons.check, color: Colors.black, size: 14)
          : Center(
              child: Text(
                step.toString(),
                style: AppText.onest(
                  size: 12,
                  weight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }
}

/// One numbered step of the sign-in flow: indicator, title, description and
/// an action widget underneath.
class LoginStepTile extends StatelessWidget {
  const LoginStepTile({
    super.key,
    required this.title,
    required this.description,
    required this.action,
    required this.isComplete,
    required this.isDim,
    required this.step,
  });

  final String title;
  final Widget description;
  final Widget action;
  final bool isComplete;
  final bool isDim;
  final int step;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: isDim ? 0.5 : 1.0,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepIndicator(isComplete: isComplete, step: step),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppText.bodyMedium(
                  color: Colors.white,
                  weight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              description,
              const SizedBox(height: AppSpacing.md),
              action,
            ],
          ),
        ),
      ],
    ),
  );
}
