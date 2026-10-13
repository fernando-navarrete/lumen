import 'package:flutter/material.dart';
import 'package:lumen/components/brand_lockup.dart';
import 'package:lumen/components/glowing_square.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

/// Left half of the login card: brand mark, glowing logo and tagline.
class BrandingPanel extends StatelessWidget {
  const BrandingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: const Border(
          right: BorderSide(color: AppColors.border09, width: 0.75),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withAlpha(25),
            AppColors.backgroundIndigo.withAlpha(34),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BrandLockup(),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGlow.withAlpha(64),
                          blurRadius: 24,
                          spreadRadius: 1,
                          offset: const Offset(0, 0),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withAlpha(25),
                        width: 1.8,
                      ),
                      color: AppColors.primary.withAlpha(16),
                    ),
                    child: const Center(child: GlowingSquare(width: 54)),
                  ),
                ),
              ),
            ),
            FractionallySizedBox(
              widthFactor: 0.7,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Your GOG library, unwrapped.",
                    style: AppText.onest(
                      size: 21.0,
                      weight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    "An unofficial client. Lumen never sees your password - you sign in on GOG's own page and hand back a one-time code.",
                    style: AppText.body(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
