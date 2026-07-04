import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
}
