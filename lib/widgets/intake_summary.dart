import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../engine/macro_split.dart';
import '../l10n/l10n.dart';
import '../models/food_log_entry.dart';

/// The day's intake: a calorie gauge, where the energy came from (C/P/F) and
/// a bar per macronutrient. Shared by Today and the diary.
class IntakeSummary extends StatelessWidget {
  const IntakeSummary({super.key, required this.totals, this.targets});

  final FoodLogTotals totals;

  /// From calculateNutritionTargets; null without a profile.
  final Map<String, dynamic>? targets;

  @override
  Widget build(BuildContext context) {
    final calorieTarget = (targets?['target_calories'] as num?)?.toDouble();
    final proteinTarget = (targets?['protein_target'] as num?)?.toDouble();
    final macroTargets = calorieTarget == null || proteinTarget == null
        ? null
        : estimateMacroTargets(calories: calorieTarget, protein: proteinTarget);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CalorieGauge(eaten: totals.calories, target: calorieTarget),
        const SizedBox(height: 12),
        MacroChips(totals: totals),
        const SizedBox(height: 16),
        MacroBars(totals: totals, targets: macroTargets),
      ],
    );
  }
}

/// A 240° arc that fills as calories are eaten, the calories left in the
/// middle. Turns amber past the target. Without a target it shows the
/// calories eaten.
class CalorieGauge extends StatelessWidget {
  const CalorieGauge({super.key, required this.eaten, this.target});

  final double eaten;
  final double? target;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final number = context.formatNumber;
    final target = this.target;
    final semantics = target == null
        ? '${number(eaten)} kcal'
        : '${l10n.diaryCaloriesProgress(number(eaten), number(target))}. '
            '${eaten <= target ? l10n.diaryRemaining(number(target - eaten)) : l10n.diaryOver(number(eaten - target))}';
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: LayoutBuilder(builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, 260.0);
        // Grows from zero the first time, then from the previous value.
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: eaten),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, shown, _) {
            final over = target != null && shown > target;
            final big = target == null ? shown : (target - shown).abs();
            return Column(
              children: [
                SizedBox(
                  width: width,
                  height: width * 0.72,
                  child: CustomPaint(
                    painter: _GaugePainter(
                      fraction: target == null || target <= 0
                          ? 0
                          : (shown / target).clamp(0.0, 1.0),
                      over: over,
                      track: CyberColors.surfaceAlt,
                      colors: over
                          ? [CyberColors.warning, CyberColors.warning]
                          : [CyberColors.cyan, CyberColors.magenta],
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(top: width * 0.14),
                      child: Column(
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              number(big),
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: over ? CyberColors.warning : null,
                                  ),
                            ),
                          ),
                          Text(
                            target == null
                                ? l10n.gaugeEatenLabel
                                : over
                                    ? l10n.gaugeOverLabel
                                    : l10n.gaugeLeftLabel,
                            style: TextStyle(color: CyberColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (target != null)
                  Text(
                    l10n.diaryCaloriesProgress(number(shown), number(target)),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
              ],
            );
          },
        );
      }),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.fraction,
    required this.over,
    required this.track,
    required this.colors,
  });

  final double fraction;
  final bool over;
  final Color track;
  final List<Color> colors;

  static const _start = 150 * math.pi / 180; // lower left
  static const _sweep = 240 * math.pi / 180; // open at the bottom

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.075;
    final radius = size.width / 2 - stroke / 2;
    final rect = Rect.fromCircle(
        center: Offset(size.width / 2, size.width / 2), radius: radius);
    Paint arc(Shader? shader, Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color
      ..shader = shader;
    canvas.drawArc(rect, _start, _sweep, false, arc(null, track));
    if (fraction <= 0) return;
    final gradient = SweepGradient(
      startAngle: _start,
      endAngle: _start + _sweep,
      colors: colors,
      transform: const GradientRotation(0),
    ).createShader(rect);
    canvas.drawArc(
        rect, _start, _sweep * fraction, false, arc(gradient, colors.first));
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.fraction != fraction ||
      old.over != over ||
      old.track != track ||
      old.colors.first != colors.first ||
      old.colors.last != colors.last;
}

/// The colour each macronutrient has in the chips and bars.
Color macroColor(String macro) => switch (macro) {
      'carbs' => CyberColors.cyan,
      'protein' => CyberColors.lime,
      _ => CyberColors.magenta,
    };

/// "C 46%  P 24%  B 30%": the share of the eaten energy each one gave.
class MacroChips extends StatelessWidget {
  const MacroChips({super.key, required this.totals});

  final FoodLogTotals totals;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shares = energyShares(totals);
    final items = [
      ('carbs', l10n.macroCarbs, shares?.carbs),
      ('protein', l10n.macroProtein, shares?.protein),
      ('fat', l10n.macroFat, shares?.fat),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final (macro, name, share) in items)
          Semantics(
            label: '$name ${share == null ? '–' : '${share.round()}%'}',
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: macroColor(macro),
                  child: Text(
                    name.characters.first.toUpperCase(),
                    style: TextStyle(
                      color: CyberColors.background,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  share == null ? '–' : '${share.round()}%',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Carbs, protein and fat side by side: a bar and "eaten / target g" each.
class MacroBars extends StatelessWidget {
  const MacroBars({super.key, required this.totals, this.targets});

  final FoodLogTotals totals;
  final MacroTargets? targets;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      ('carbs', l10n.macroCarbs, totals.carbs, targets?.carbs),
      ('protein', l10n.macroProtein, totals.protein, targets?.protein),
      ('fat', l10n.macroFat, totals.fat, targets?.fat),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, (macro, name, eaten, target)) in items.indexed) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: _MacroBar(
                macro: macro, name: name, eaten: eaten, target: target),
          ),
        ],
      ],
    );
  }
}

class _MacroBar extends StatelessWidget {
  const _MacroBar({
    required this.macro,
    required this.name,
    required this.eaten,
    required this.target,
  });

  final String macro;
  final String name;
  final double eaten;
  final double? target;

  @override
  Widget build(BuildContext context) {
    final number = context.formatNumber;
    final target = this.target;
    final over = target != null && eaten > target;
    final amount = target == null
        ? '${number(eaten)} g'
        : '${number(eaten)} / ${number(target)} g';
    return Semantics(
      label: '$name $amount',
      excludeSemantics: true,
      child: Column(
        children: [
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: CyberColors.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(
                begin: 0,
                end: target == null || target <= 0
                    ? 0
                    : (eaten / target).clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: value,
                color: over ? CyberColors.warning : macroColor(macro),
                backgroundColor: CyberColors.surfaceAlt,
              ),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(amount,
                style: TextStyle(
                    color: over ? CyberColors.warning : CyberColors.text,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// "🔥 3 ngày" in a card's title row; dimmed while today is not logged yet.
class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.days, required this.loggedToday});

  final int days;
  final bool loggedToday;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (days == 0) return const SizedBox.shrink();
    final color = CyberColors.warning;
    return Tooltip(
      message: loggedToday
          ? l10n.streakDays('$days')
          : '${l10n.streakDays('$days')} • ${l10n.streakKeep}',
      child: Semantics(
        label: l10n.streakDays('$days'),
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: loggedToday
                ? color.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.whatshot_rounded, size: 16, color: color),
              const SizedBox(width: 4),
              Text(l10n.streakBadge('$days'),
                  style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}
