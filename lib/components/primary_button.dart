import 'package:flutter/material.dart';
import 'package:lumen/common/clickable_container.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.onTap,
    required this.child,
    this.glowing = false,
    this.enabled = true,
    this.large = false,
  });

  /// Convenience for the common icon + label content.
  factory PrimaryButton.icon({
    Key? key,
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    Color? foreground,
    bool glowing = false,
    bool enabled = true,
    bool large = false,
  }) {
    final color = foreground ?? (glowing ? AppColors.onPrimary : Colors.white);
    return PrimaryButton(
      key: key,
      onTap: onTap,
      glowing: glowing,
      enabled: enabled,
      large: large,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.xs,
        children: [
          Icon(icon, color: color, size: large ? 20 : 24),
          Text(label, style: _labelStyle(color, glowing: glowing, large: large)),
        ],
      ),
    );
  }

  /// Label style matching the design's CTA typography: large glowing CTAs
  /// are 15/w700, everything else uses the standard button style.
  static TextStyle _labelStyle(
    Color color, {
    required bool glowing,
    required bool large,
  }) => large && glowing
      ? AppText.onest(size: 15, weight: FontWeight.w700, color: color)
      : AppText.button(color: color);

  final VoidCallback onTap;
  final Widget child;
  final bool glowing;
  final bool enabled;

  /// Hero-sized call to action: bigger radius, padding and glow.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final button = ClickableContainer(
      onTap: enabled ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: glowing ? AppColors.primary : AppColors.fill10,
          borderRadius: BorderRadius.circular(
            large ? AppRadii.buttonLarge : AppRadii.control,
          ),
          boxShadow: glowing
              ? [
                  BoxShadow(
                    offset: Offset(0, large ? 8 : 2),
                    blurRadius: large ? 24 : 18,
                    color: AppColors.primaryGlow,
                  ),
                ]
              : null,
          border: !glowing ? Border.all(color: AppColors.border14) : null,
        ),
        child: Padding(
          padding: large
              ? EdgeInsets.symmetric(horizontal: glowing ? 30.0 : 20.0, vertical: 13.0)
              : const EdgeInsets.symmetric(horizontal: 20.0, vertical: 11.0),
          child: child,
        ),
      ),
    );
    return enabled ? button : Opacity(opacity: 0.5, child: button);
  }
}
