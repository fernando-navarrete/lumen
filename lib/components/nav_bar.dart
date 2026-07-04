import 'package:flutter/material.dart';
import 'package:gogdl2_flutter/components/brand_lockup.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';

class NavBar extends StatelessWidget {
  const NavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      height: 74,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(8),
        border: Border(bottom: BorderSide(color: AppColors.border08)),
      ),
      child: const BrandLockup(),
    );
  }
}
