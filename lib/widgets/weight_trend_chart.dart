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
              // The app's font, growing with the system text size.
              labelStyle: Theme.of(context).textTheme.bodySmall,
              textScaler: MediaQuery.textScalerOf(context),
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
    this.labelStyle,
    this.textScaler = TextScaler.noScaling,
  });

  final List<WeightEntry> entries;
  final String Function(double) formatWeight;
  final Color lineColor;
  final Color labelColor;
  final Color gridColor;
  final TextStyle? labelStyle;
  final TextScaler textScaler;

  TextPainter _text(String value) => TextPainter(
        text: TextSpan(
          text: value,
          style: (labelStyle ?? const TextStyle())
              .copyWith(color: labelColor, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty || size.width < 100) return;
    final lowest = entries.map((e) => e.weight).reduce(math.min);
    final highest = entries.map((e) => e.weight).reduce(math.max);
    final margin = math.max((highest - lowest) * .15, .5);
    final lower = math.max(0.0, lowest - margin);
    final upper = highest + margin;
    final firstTime = entries.first.recordedAt.millisecondsSinceEpoch;
    final timeRange =
        entries.last.recordedAt.millisecondsSinceEpoch - firstTime;

    // Labels are measured first, so large system text widens the left
    // margin and lowers the dates instead of drawing over the chart.
    final weightLabels = [
      for (var index = 0; index < 3; index++)
        _text('${formatWeight(upper - (upper - lower) * index / 2)}\u00A0kg'),
    ];
    final firstDate = _text(formatDate(entries.first.recordedAt));
    final lastDate = _text(formatDate(entries.last.recordedAt));
    final left = weightLabels.map((label) => label.width).reduce(math.max) + 8;
    final top = weightLabels.first.height / 2;
    final right = size.width - 4;
    final bottom = size.height - firstDate.height - 8;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index < 3; index++) {
      final y = top + (bottom - top) * index / 2;
      canvas.drawLine(Offset(left, y), Offset(right, y), grid);
      final label = weightLabels[index];
      label.paint(canvas, Offset(0, y - label.height / 2));
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
    final dateTop = bottom + 6;
    firstDate.paint(canvas, Offset(left, dateTop));
    final lastLeft = right - lastDate.width;
    if (timeRange != 0 && lastLeft >= left + firstDate.width + 12) {
      lastDate.paint(canvas, Offset(lastLeft, dateTop));
    }
  }

  @override
  bool shouldRepaint(covariant _WeightPainter oldDelegate) =>
      oldDelegate.entries != entries ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.labelColor != labelColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelStyle != labelStyle ||
      oldDelegate.textScaler != textScaler;
}
