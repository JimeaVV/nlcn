import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../l10n/l10n.dart';
import '../models/recommendation_models.dart';
import 'cyber_card.dart';
import 'metric_tile.dart';

class MealResult extends StatelessWidget {
  const MealResult({super.key, required this.recommendation});

  final DietRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final plan = recommendation.plan;
    final target = recommendation.targetCalories;
    final meetsTargets = plan.meetsTargets(target);
    final accent = meetsTargets ? CyberColors.lime : Colors.orange;
    final l10n = context.l10n;
    String format(double value, [int decimals = 0]) =>
        context.formatNumber(value, decimals: decimals);
    return Column(
      children: [
        CyberCard(
          title: l10n.mealTargetsTitle,
          icon: Icons.speed_rounded,
          child: Row(children: [
            Expanded(
                child: MetricTile(
                    label: 'BMR',
                    value: format(recommendation.bmr),
                    unit: 'kcal')),
            const SizedBox(width: 8),
            Expanded(
                child: MetricTile(
                    label: 'TDEE',
                    value: format(recommendation.tdee),
                    unit: 'kcal')),
            const SizedBox(width: 8),
            Expanded(
                child: MetricTile(
                    label: l10n.targetLabel,
                    value: format(target),
                    unit: 'kcal')),
          ]),
        ),
        const SizedBox(height: 14),
        CyberCard(
          title: l10n.mealComparisonTitle,
          icon: meetsTargets
              ? Icons.check_circle_outline_rounded
              : Icons.info_outline_rounded,
          accent: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  meetsTargets ? l10n.mealWithinTarget : l10n.mealOutsideTarget,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _Comparison(
                  label: l10n.caloriesLabel,
                  actual: plan.totalCalories,
                  target: target,
                  difference: plan.calorieDifference(target),
                  percent: plan.calorieDeviationPercent(target),
                  unit: 'kcal'),
              const SizedBox(height: 12),
              _Comparison(
                  label: l10n.proteinLabel,
                  actual: plan.totalProtein,
                  target: plan.proteinTarget,
                  difference: plan.proteinDifference,
                  percent: plan.proteinDeviationPercent,
                  unit: 'g'),
              const SizedBox(height: 10),
              Text(l10n.mealToleranceNote,
                  style: TextStyle(color: CyberColors.muted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        CyberCard(
          title: l10n.mealsTitle,
          icon: Icons.ramen_dining_rounded,
          accent: CyberColors.magenta,
          child: Column(
            children: recommendation.plan.meals.entries.map((entry) {
              final meal = entry.value;
              final label = l10n.mealLabel(entry.key);
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: CyberColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            color: CyberColors.magenta,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    ...meal.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text('• ${item.displayName}',
                              style: TextStyle(color: CyberColors.text)),
                        )),
                    const SizedBox(height: 8),
                    Text(context.l10n.mealMacroLine(
                        format(meal.calories),
                        format(meal.protein, 1),
                        format(meal.carbohydrates, 1),
                        format(meal.fat, 1))),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison(
      {required this.label,
      required this.actual,
      required this.target,
      required this.difference,
      required this.percent,
      required this.unit});

  final String label;
  final double actual;
  final double target;
  final double difference;
  final double percent;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final decimals = unit == 'g' ? 1 : 0;
    String format(double value) =>
        context.formatNumber(value, decimals: decimals);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${format(actual)} / ${format(target)}\u00A0$unit',
            style: TextStyle(
                color: CyberColors.text, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
            context.l10n.comparisonDifference(
              context.formatSigned(difference, decimals: decimals),
              unit,
              context.formatSigned(percent, decimals: 1),
            ),
            style: TextStyle(color: CyberColors.muted)),
      ],
    );
  }
}
