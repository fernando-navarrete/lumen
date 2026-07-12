import 'package:flutter/material.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';

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
        color: AppColors.fill04,
        border: Border.all(color: AppColors.border08),
        borderRadius: BorderRadius.circular(borderRadius),
      );

  /// Selected/active row: teal-tinted fill with a teal border.
  static BoxDecoration highlightedPanel({
    double borderRadius = AppRadii.card,
  }) => BoxDecoration(
    color: AppColors.primaryTint10,
    border: Border.all(color: AppColors.primaryGlow, width: 1.2),
    borderRadius: BorderRadius.circular(borderRadius),
  );

  /// Dark inset code/input block.
  static BoxDecoration get codeBlock => BoxDecoration(
    color: AppColors.codeBackground,
    borderRadius: BorderRadius.circular(AppRadii.control),
    border: Border.all(color: AppColors.border12, width: 1.2),
  );

  /// Glass section card: translucent dark fill whose top sliver is nudged
  /// toward white, standing in for the design's inset top highlight
  /// (Flutter's BoxShadow has no inset support).
  static BoxDecoration glassCard({double borderRadius = AppRadii.section}) =>
      BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.glassHighlight, AppColors.glass55],
          stops: [0.0, 0.06],
        ),
        border: Border.all(color: AppColors.border09),
        borderRadius: BorderRadius.circular(borderRadius),
      );

  /// Glass list row (downloads cards): flat glass fill, no highlight.
  static BoxDecoration glassRow({double borderRadius = AppRadii.cardLarge}) =>
      BoxDecoration(
        color: AppColors.glass55,
        border: Border.all(color: AppColors.border09),
        borderRadius: BorderRadius.circular(borderRadius),
      );

  /// Light translucent input/select surface.
  static BoxDecoration get input => BoxDecoration(
    color: AppColors.fill06,
    border: Border.all(color: AppColors.border12),
    borderRadius: BorderRadius.circular(AppRadii.control),
  );

  /// Dark mono text input (launch options, env vars).
  static BoxDecoration monoInput({double borderRadius = AppRadii.control}) =>
      BoxDecoration(
        color: AppColors.inputFill,
        border: Border.all(color: AppColors.border12),
        borderRadius: BorderRadius.circular(borderRadius),
      );

  /// Resolved-command preview box.
  static BoxDecoration get previewBox => BoxDecoration(
    color: AppColors.codeBackground,
    border: Border.all(color: AppColors.border07),
    borderRadius: BorderRadius.circular(AppRadii.control),
  );

  /// Hero banner shell: large radius, hairline border, deep drop shadow.
  static BoxDecoration get heroCard => BoxDecoration(
    border: Border.all(color: AppColors.border09),
    borderRadius: BorderRadius.circular(AppRadii.hero),
    boxShadow: const [
      BoxShadow(
        color: Color(0x73000000),
        blurRadius: 50,
        offset: Offset(0, 18),
      ),
    ],
  );

  /// Left-to-right scrim over hero cover art.
  static BoxDecoration heroScrim({double borderRadius = AppRadii.hero}) =>
      BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xEE070A0E), Color(0x80070A0E), Color(0x1A070A0E)],
          stops: [0.0, 0.52, 1.0],
        ),
      );

  /// Bottom-up scrim behind game-card status pills.
  static BoxDecoration get cardScrim => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x00000000), Color(0xD6000000)],
    ),
  );

  /// Grayscale + darken filter for not-installed cover art
  /// (grayscale 0.35 · brightness 0.82).
  static const ColorFilter dimmedCover = ColorFilter.matrix([
    0.5940, 0.2053, 0.0207, 0, 0, //
    0.0610, 0.7383, 0.0207, 0, 0, //
    0.0610, 0.2053, 0.5537, 0, 0, //
    0, 0, 0, 1, 0,
  ]);
}
