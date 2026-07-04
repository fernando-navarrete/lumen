import 'package:flutter/material.dart';
import 'package:gogdl2_flutter/components/glowing_square.dart';
import 'package:gogdl2_flutter/theme/text_styles.dart';

/// The "glowing square + Lumen" logo lockup shown in the nav bar and on
/// the login screen.
class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.squareWidth = 27,
    this.spacing = 12,
    this.textSize = 18,
  });

  final double squareWidth;
  final double spacing;
  final double textSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlowingSquare(width: squareWidth),
        SizedBox(width: spacing),
        Text(
          'Lumen',
          style: AppText.onest(
            size: textSize,
            weight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
