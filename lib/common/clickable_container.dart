import 'package:flutter/material.dart';
import 'package:lumen/theme/app_colors.dart';
import 'package:lumen/theme/app_dimens.dart';

/// A tappable surface: click cursor, keyboard focus (Tab), Enter/Space
/// activation and button semantics. With a null [onTap] it is disabled: not
/// focusable, basic cursor, reported as a disabled button.
///
/// The teal focus outline shows only for keyboard focus, never after a click.
/// Give icon-only children a [semanticLabel]; [focusRadius] should match the
/// child's own corner radius.
class ClickableContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double focusRadius;

  const ClickableContainer({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.focusRadius = AppRadii.chip,
  });

  @override
  State<ClickableContainer> createState() => _ClickableContainerState();
}

class _ClickableContainerState extends State<ClickableContainer> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: onTap != null,
        mouseCursor: onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onTap?.call();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        child: GestureDetector(
          onTap: onTap,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: _focused
                  ? Border.all(color: AppColors.primary, width: 2)
                  : null,
              borderRadius: BorderRadius.circular(widget.focusRadius),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
