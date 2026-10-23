import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../engine/daily_habits.dart';
import '../l10n/l10n.dart';

/// One glass per [waterGlassMl] up to the daily target. Tapping the fifth
/// glass means five glasses drunk; tapping the last full one again takes it
/// back. Glasses past the target show as "+2".
class WaterGlasses extends StatelessWidget {
  const WaterGlasses({super.key, required this.ml, required this.onSet});

  final int ml;

  /// Called with the new total in millilitres.
  final ValueChanged<int> onSet;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const glasses = waterTargetMl ~/ waterGlassMl;
    final full = ml ~/ waterGlassMl;
    final extra = full - glasses;
    Widget glass(int i) => Semantics(
          button: true,
          selected: i < full,
          label: l10n.waterGlassSemantics('${i + 1}', '$glasses'),
          excludeSemantics: true,
          child: InkResponse(
            key: ValueKey('water-glass-$i'),
            radius: 24,
            onTap: () => onSet((full == i + 1 ? i : i + 1) * waterGlassMl),
            child: SizedBox(
              height: 48,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  i < full
                      ? Icons.local_drink_rounded
                      : Icons.local_drink_outlined,
                  key: ValueKey(i < full),
                  size: 28,
                  color: i < full ? CyberColors.cyan : CyberColors.muted,
                ),
              ),
            ),
          ),
        );
    return LayoutBuilder(builder: (context, constraints) {
      // Each glass at least 48 dp wide, so a tap does not land on the next
      // one; when a row is too narrow the glasses split evenly over two.
      final rows = (glasses * 48 / constraints.maxWidth).ceil().clamp(1, 2);
      final perRow = (glasses / rows).ceil();
      return Column(
        children: [
          for (var row = 0; row < rows; row++)
            Row(
              children: [
                for (var i = row * perRow;
                    i < (row + 1) * perRow && i < glasses;
                    i++)
                  Expanded(child: glass(i)),
                if (row == rows - 1 && extra > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text('+$extra',
                        style: TextStyle(
                            color: CyberColors.cyan,
                            fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
        ],
      );
    });
  }
}
