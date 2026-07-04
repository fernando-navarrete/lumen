import 'package:flutter/material.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';

/// Standard centered spinner shown while async data resolves.
class CenteredLoader extends StatelessWidget {
  const CenteredLoader({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: AppColors.primary));
}
