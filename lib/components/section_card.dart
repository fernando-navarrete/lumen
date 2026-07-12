import 'package:flutter/material.dart';
import 'package:lumen/theme/app_decorations.dart';
import 'package:lumen/theme/app_dimens.dart';
import 'package:lumen/theme/text_styles.dart';

/// Glass section card with an optional title, description and trailing
/// action, used for settings groups and the game facts panel.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.description,
    this.trailing,
    required this.child,
  }) : _rows = false;

  /// Variant for cards that only hold a list of divided rows: tighter
  /// vertical padding so the rows' own padding sets the rhythm.
  const SectionCard.rows({super.key, required this.child})
    : title = null,
      description = null,
      trailing = null,
      _rows = true;

  final String? title;
  final String? description;
  final Widget? trailing;
  final Widget child;
  final bool _rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: _rows
          ? const EdgeInsets.symmetric(horizontal: 18, vertical: 6)
          : const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: AppDecorations.glassCard(),
      child: _rows
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(title!, style: AppText.cardTitle()),
                      ),
                      ?trailing,
                    ],
                  ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(description!, style: AppText.cardDesc()),
                ],
                if (title != null || description != null)
                  const SizedBox(height: AppSpacing.md),
                child,
              ],
            ),
    );
  }
}
