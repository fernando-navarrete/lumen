import 'package:flutter/material.dart';
import 'package:lumen/components/primary_button.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_decorations.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

/// Message with a Retry action, for when a fetch failed or came back empty.
class RetryMessage extends StatelessWidget {
  const RetryMessage({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: AppDecorations.glassRow(),
    child: Column(
      spacing: AppSpacing.md,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppText.bodyMedium(color: AppColors.text70),
        ),
        PrimaryButton(
          onTap: onRetry,
          child: Text('Retry', style: AppText.button(color: Colors.white)),
        ),
      ],
    ),
  );
}
