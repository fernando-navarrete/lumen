import 'package:flutter/material.dart';
import 'package:gogdl2_flutter/common/clickable_container.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';
import 'package:gogdl2_flutter/theme/app_dimens.dart';
import 'package:gogdl2_flutter/theme/text_styles.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.onTap,
    required this.child,
    this.glowing = false,
    this.enabled = true,
  });

  /// Convenience for the common icon + label content.
  factory PrimaryButton.icon({
    Key? key,
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    Color foreground = Colors.white,
    bool glowing = false,
    bool enabled = true,
  }) => PrimaryButton(
    key: key,
    onTap: onTap,
    glowing: glowing,
    enabled: enabled,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.xs,
      children: [
        Icon(icon, color: foreground),
        Text(label, style: AppText.button(color: foreground)),
      ],
    ),
  );

  final VoidCallback onTap;
  final Widget child;
  final bool glowing;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final button = ClickableContainer(
      onTap: enabled ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: glowing ? AppColors.primary : AppColors.border08,
          borderRadius: BorderRadius.circular(AppRadii.control),
          boxShadow: glowing
              ? [
                  BoxShadow(
                    offset: Offset(0, 2),
                    blurRadius: 18,
                    color: AppColors.primaryGlow,
                  ),
                ]
              : null,
          border: !glowing ? Border.all(color: AppColors.border12) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20.0,
            vertical: 11.0,
          ),
          child: child,
        ),
      ),
    );
    return enabled ? button : Opacity(opacity: 0.5, child: button);
  }
}
