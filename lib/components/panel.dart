import 'package:flutter/material.dart';
import 'package:gogdl2_flutter/theme/app_decorations.dart';

/// Flat bordered surface used for detail cards and list rows.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: AppDecorations.panel(),
    child: child,
  );
}
