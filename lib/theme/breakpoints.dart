import 'package:lumen/theme/app_dimens.dart';

/// Widths (of the space a widget is laid out in, not the window) where
/// layouts change.
abstract final class Breakpoints {
  /// Below this the detail tabs drop their side column.
  static const double compact = 600;

  /// Above this the side column grows from [SideColumn.regular] to
  /// [SideColumn.wide].
  static const double wide = 1200;

  /// Below this the login card drops its branding pane and shows only the
  /// sign-in pane.
  static const double loginSplit = 760;
}

/// Fixed widths of the detail tabs' side column.
abstract final class SideColumn {
  static const double regular = 280;
  static const double wide = 340;

  /// Space between the main column and the side column.
  static const double gap = AppSpacing.lg;
}

/// Width of the side column for a tab that is [availableWidth] wide; 0 when
/// the column is hidden.
double sideColumnWidth(double availableWidth) {
  if (availableWidth < Breakpoints.compact) return 0;
  if (availableWidth <= Breakpoints.wide) return SideColumn.regular;
  return SideColumn.wide;
}
