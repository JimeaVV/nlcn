import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';

class CyberCard extends StatelessWidget {
  const CyberCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.accent = CyberColors.cyan,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Color accent;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: CyberColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.09),
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
                  Icon(icon, color: accent, size: 21),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
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
