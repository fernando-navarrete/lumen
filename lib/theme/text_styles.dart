import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lumen/theme/app_colors.dart';

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

  /// 44px hero banner titles.
  static TextStyle get heroTitle => onest(
    size: 44.0,
    weight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: -0.88,
    height: 1.0,
  );

  /// 24px page titles ("Downloads", "Settings").
  static TextStyle get pageTitle => onest(
    size: 24.0,
    weight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: -0.48,
  );

  /// 18px in-page section titles ("Your library").
  static TextStyle get sectionTitle => onest(
    size: 18.0,
    weight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: -0.18,
  );

  /// 15px card/row titles (glass card headers, download names).
  static TextStyle cardTitle({Color color = Colors.white}) =>
      onest(size: 15.0, weight: FontWeight.w700, color: color);

  /// Uppercase micro section labels ("MEDIA", "ACTIVE") — callers uppercase.
  static TextStyle get microLabel => onest(
    size: 12.0,
    weight: FontWeight.w700,
    color: AppColors.text40,
    letterSpacing: 0.6,
  );

  /// Mono uppercase eyebrow over hero titles ("CONTINUE PLAYING").
  static TextStyle get eyebrow => monospace(
    size: 10.0,
    weight: FontWeight.w400,
    color: AppColors.primaryLight,
    letterSpacing: 1.8,
  );

  /// 12px filter-chip labels.
  static TextStyle chip({required Color color}) =>
      onest(size: 12.0, weight: FontWeight.w600, color: color);

  /// 13.5px nav pill labels.
  static TextStyle navPill({
    required Color color,
    FontWeight weight = FontWeight.w600,
  }) => onest(size: 13.5, weight: weight, color: color);

  /// 12.5px descriptions under card titles.
  static TextStyle cardDesc({Color color = AppColors.textSecondary}) =>
      onest(size: 12.5, weight: FontWeight.w400, color: color);

  /// 13px meta rows (hero status/version spans, facts rows).
  static TextStyle meta({
    Color color = AppColors.text70,
    FontWeight weight = FontWeight.w400,
  }) => onest(size: 13.0, weight: weight, color: color);

  /// 14.5px long-form copy (game descriptions).
  static TextStyle get bodyLong => onest(
    size: 14.5,
    weight: FontWeight.w400,
    color: AppColors.text80,
    height: 1.7,
  );

  /// 11px status pills on game cards.
  static TextStyle statusPill({required Color color}) =>
      onest(size: 11.0, weight: FontWeight.w600, color: color);

  /// 12.5px mono values in key/value rows.
  static TextStyle monoValue({Color color = AppColors.text70}) =>
      monospace(size: 12.5, weight: FontWeight.w400, color: color);

  /// Mono resolved-command preview text.
  static TextStyle get monoPreview => monospace(
    size: 12.0,
    weight: FontWeight.w400,
    color: AppColors.primaryLight,
    height: 1.6,
  );

  /// 10px count badges on nav pills.
  static TextStyle badge({Color color = AppColors.onPrimary}) =>
      onest(size: 10.0, weight: FontWeight.w700, color: color);
}
