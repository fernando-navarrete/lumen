import 'package:flutter/material.dart';
import 'package:lumen/theme/app_decorations.dart';

/// Flat bordered surface used for detail cards and list rows.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
    this.selected = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: selected
        ? AppDecorations.highlightedPanel()
        : AppDecorations.panel(),
    child: child,
  );
}
