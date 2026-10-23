import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/weight_entry.dart';

/// A small local chart; the measurement list remains the accessible data source.
class WeightTrendChart extends StatelessWidget {
  const WeightTrendChart({super.key, required this.entries});

  final List<WeightEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final ordered = List<WeightEntry>.of(entries)
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: context.l10n.weightChartSemantics(
        '${ordered.length}',
        formatDate(ordered.first.recordedAt),
        context.formatNumber(ordered.first.weight, decimals: 1),
        formatDate(ordered.last.recordedAt),
        context.formatNumber(ordered.last.weight, decimals: 1),
      ),
      child: ExcludeSemantics(
        child: SizedBox(
          width: double.infinity,
          height: 180,
          child: CustomPaint(
            painter: _WeightPainter(
              ordered,
              formatWeight: (value) => context.formatNumber(value, decimals: 1),
              lineColor: colors.primary,
              labelColor: colors.onSurfaceVariant,
              gridColor: colors.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _WeightPainter extends CustomPainter {
  _WeightPainter(
    this.entries, {
    required this.formatWeight,
    required this.lineColor,
    required this.labelColor,
    required this.gridColor,
  });

  final List<WeightEntry> entries;
  final String Function(double) formatWeight;
  final Color lineColor;
  final Color labelColor;
  final Color gridColor;

  void _label(Canvas canvas, String value, Offset position) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(color: labelColor, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, position);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty || size.width < 100) return;
    const left = 48.0;
    const top = 12.0;
    final right = size.width - 12;
    final bottom = size.height - 30;
    final lowest = entries.map((e) => e.weight).reduce(math.min);
    final highest = entries.map((e) => e.weight).reduce(math.max);
    final margin = math.max((highest - lowest) * .15, .5);
    final lower = math.max(0.0, lowest - margin);
    final upper = highest + margin;
    final firstTime = entries.first.recordedAt.millisecondsSinceEpoch;
    final timeRange =
        entries.last.recordedAt.millisecondsSinceEpoch - firstTime;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index < 3; index++) {
      final fraction = index / 2;
      final y = top + (bottom - top) * fraction;
      canvas.drawLine(Offset(left, y), Offset(right, y), grid);
      _label(
        canvas,
        '${formatWeight(upper - (upper - lower) * fraction)}\u00A0kg',
        Offset(0, y - 6),
      );
    }

    final points = entries.map((entry) {
      final fraction = timeRange == 0
          ? .5
          : (entry.recordedAt.millisecondsSinceEpoch - firstTime) / timeRange;
      return Offset(
        left + (right - left) * fraction,
        bottom - (entry.weight - lower) / (upper - lower) * (bottom - top),
      );
    }).toList(growable: false);
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, line);
    final dot = Paint()..color = lineColor;
    for (final point in points) {
      canvas.drawCircle(point, 3.5, dot);
    }
    _label(
        canvas, formatDate(entries.first.recordedAt), Offset(left, bottom + 8));
    if (timeRange != 0 && size.width >= 240) {
      _label(
        canvas,
        formatDate(entries.last.recordedAt),
        Offset(math.max(left + 80, right - 66), bottom + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeightPainter oldDelegate) =>
      oldDelegate.entries != entries ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.labelColor != labelColor ||
      oldDelegate.gridColor != gridColor;
}
