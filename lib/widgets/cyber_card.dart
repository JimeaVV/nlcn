import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';

class CyberCard extends StatelessWidget {
  const CyberCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.accent,
    this.padding = const EdgeInsets.all(18),
    this.trailing,
    this.highlight = false,
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Color? accent;
  final EdgeInsets padding;

  /// Shown at the end of the title row, e.g. an info button.
  final Widget? trailing;

  /// The one card a screen leads with gets the accent border and glow; the
  /// rest keep a quiet border, so the eye knows where to start.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final resolvedAccent = accent ?? CyberColors.cyan;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: CyberColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: highlight
                ? resolvedAccent.withValues(alpha: 0.55)
                : CyberColors.border),
        boxShadow: [
          if (highlight)
            BoxShadow(
              color: resolvedAccent.withValues(alpha: 0.09),
              blurRadius: 20,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: resolvedAccent, size: 21),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}
