import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../l10n/l10n.dart';

/// An ⓘ button for a card's title row: the card keeps its controls and the
/// explanation opens in a sheet only when wanted.
class InfoButton extends StatelessWidget {
  const InfoButton({
    super.key,
    required this.title,
    required this.paragraphs,
    this.tooltip,
  });

  final String title;
  final List<String> paragraphs;

  /// Defaults to a generic "more info".
  final String? tooltip;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip ?? context.l10n.infoTooltip,
        visualDensity: VisualDensity.compact,
        onPressed: () => show(context, title, paragraphs),
        icon: Icon(Icons.info_outline_rounded, color: CyberColors.muted),
      );

  static void show(
      BuildContext context, String title, List<String> paragraphs) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: CyberColors.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              for (final paragraph in paragraphs) ...[
                const SizedBox(height: 12),
                Text(paragraph),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
