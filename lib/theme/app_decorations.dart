import 'package:flutter/material.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';

class AppDecorations {
  /// The elevated-card look shared by the login panel, the game header and
  /// game grid cards: a soft drop shadow plus a hairline border.
  static BoxDecoration card({
    required double borderRadius,
    required Color borderColor,
    double borderWidth = 1.0,
    double blurRadius = 10,
    double spreadRadius = 5,
  }) => BoxDecoration(
    boxShadow: [
      BoxShadow(
        color: AppColors.shadow,
        blurRadius: blurRadius,
        spreadRadius: spreadRadius,
      ),
    ],
    border: Border.all(color: borderColor, width: borderWidth),
    borderRadius: BorderRadius.circular(borderRadius),
  );
}
