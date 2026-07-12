import 'package:flutter/material.dart';
import 'package:lumen/theme/app_colors.dart';

/// The teal brand square: diagonal gradient with a soft teal glow.
class GlowingSquare extends StatelessWidget {
  const GlowingSquare({super.key, required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    // Design metrics are for a 27px square; scale shadow and radius with it.
    final scale = width / 27.0;
    return Container(
      width: width,
      height: width,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: const Color(0x732DD4BF),
            blurRadius: 14 * scale,
            offset: Offset(0, 5 * scale),
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(8 * scale),
      ),
    );
  }
}
