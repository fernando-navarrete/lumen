import 'package:flutter/material.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';

class GlowingSquare extends StatelessWidget {
  const GlowingSquare({super.key, required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGlow,
            blurRadius: width / 3.375,
            spreadRadius: 1,
            offset: Offset(0, 0),
          ),
        ],
        gradient: RadialGradient(
          colors: [AppColors.primaryGlow, AppColors.primaryLight],
          center: Alignment(1, 1),
          radius: 1.5,
        ),
        borderRadius: BorderRadius.circular(width / 3.375),
      ),
    );
  }
}
