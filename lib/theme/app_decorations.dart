import 'package:flutter/material.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';
import 'package:gogdl2_flutter/theme/app_dimens.dart';

class AppDecorations {
  /// The elevated-card look shared by the login panel, the game header and
  /// game grid cards: a soft drop shadow plus a hairline border.
  static BoxDecoration card({
    double borderRadius = AppRadii.card,
    Color borderColor = AppColors.border12,
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

  /// Flat bordered panel (no shadow): details card, build list rows.
  static BoxDecoration panel({double borderRadius = AppRadii.card}) =>
      BoxDecoration(
        color: AppColors.fill08,
        border: Border.all(color: AppColors.border12),
        borderRadius: BorderRadius.circular(borderRadius),
      );

  /// Dark inset code/input block.
  static BoxDecoration get codeBlock => BoxDecoration(
    color: AppColors.codeBackground,
    borderRadius: BorderRadius.circular(AppRadii.control),
    border: Border.all(color: AppColors.border12, width: 1.2),
  );
}
