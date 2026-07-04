import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gogdl2_flutter/theme/app_colors.dart';

class AppText {
  static TextStyle onest({
    required double size,
    required FontWeight weight,
    required Color color,
    double? letterSpacing,
    double? height,
  }) => GoogleFonts.onest(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
  static TextStyle monospace({
    required double size,
    required FontWeight weight,
    required Color color,
    double? letterSpacing,
    double? height,
  }) => TextStyle(
    fontFamily: 'monospace',
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

  /// Small body copy, e.g. step descriptions and helper text.
  static TextStyle body({required Color color}) =>
      onest(size: 12.0, weight: FontWeight.w200, color: color);

  /// Inline code / redirect-URL snippets.
  static TextStyle code({required Color color}) =>
      monospace(size: 12.0, weight: FontWeight.w500, color: color);

  /// Uppercase section headers, e.g. "MEDIA" / "DETAILS".
  static TextStyle get sectionLabel =>
      monospace(size: 13.0, weight: FontWeight.w500, color: AppColors.textMuted);

  /// Standard 14px body text (summaries, status rows, tab labels).
  static TextStyle bodyMedium({
    required Color color,
    FontWeight weight = FontWeight.w400,
  }) => onest(size: 14.0, weight: weight, color: color);

  /// Button labels.
  static TextStyle button({required Color color}) =>
      onest(size: 14.0, weight: FontWeight.w600, color: color);

  /// 12px secondary copy, e.g. release dates and install status.
  static TextStyle caption({required Color color}) =>
      onest(size: 12.0, weight: FontWeight.w400, color: color);
}
