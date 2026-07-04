import 'package:flutter/material.dart';
import 'package:gogdl2_flutter/components/brand_lockup.dart';
import 'package:gogdl2_flutter/components/glowing_square.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';
import 'package:gogdl2_flutter/theme/app_dimens.dart';
import 'package:gogdl2_flutter/theme/text_styles.dart';

/// Left half of the login card: brand mark, glowing logo and tagline.
class BrandingPanel extends StatelessWidget {
  const BrandingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    final width = (size.width - (size.width * 0.2) - 2) * 0.45;
    return Container(
      width: width,
      height: (size.height - (size.height * 0.1)),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadii.panel),
          bottomLeft: Radius.circular(AppRadii.panel),
        ),
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
            SizedBox(
              width: width * 0.7,
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
