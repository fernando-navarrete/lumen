import 'package:flutter/material.dart';
import 'package:lumen/theme/breakpoints.dart';

/// A tab's main column plus a fixed-width side column that hides when the tab
/// is narrow. With no [side] the column is an empty spacer, which keeps the
/// main column aligned with tabs that do show one.
class SideColumnLayout extends StatelessWidget {
  const SideColumnLayout({super.key, required this.main, this.side});

  /// Key of the side column's box, present only when it is shown.
  static const sideKey = ValueKey('side-column');

  final Widget main;
  final Widget? side;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double sideWidth = sideColumnWidth(constraints.maxWidth);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: main),
            if (sideWidth > 0) ...[
              const SizedBox(width: SideColumn.gap),
              SizedBox(key: sideKey, width: sideWidth, child: side),
            ],
          ],
        );
      },
    );
  }
}
