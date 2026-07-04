import 'package:flutter/material.dart';
import 'package:gogdl2_flutter/common/clickable_container.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.onTap,
    required this.child,
    this.glowing = false,
  });
  final VoidCallback onTap;
  final Widget child;
  final bool glowing;

  @override
  Widget build(BuildContext context) => ClickableContainer(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: glowing ? AppColors.primary : AppColors.border08,
        borderRadius: BorderRadius.circular(11.0),
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
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 11.0),
        child: child,
      ),
    ),
  );
}
