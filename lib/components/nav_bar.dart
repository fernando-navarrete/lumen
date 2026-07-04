import 'package:flutter/material.dart';
import 'package:gogdl2_flutter/components/glowing_square.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';
import 'package:gogdl2_flutter/theme/text_styles.dart';

class NavBar extends StatelessWidget {
  const NavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24),
      height: 74,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(8),
        border: Border(bottom: BorderSide(color: AppColors.border08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GlowingSquare(width: 27),
          SizedBox(width: 12),
          Text(
            "Lumen",
            style: AppText.onest(
              size: 18,
              weight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
