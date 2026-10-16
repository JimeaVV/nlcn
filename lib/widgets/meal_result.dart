import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../models/recommendation_models.dart';
import 'cyber_card.dart';
import 'metric_tile.dart';

String _format(double value, [int decimals = 0]) =>
    value.toStringAsFixed(decimals).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},');

class MealResult extends StatelessWidget {
  const MealResult({super.key, required this.recommendation});

  final DietRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final plan = recommendation.plan;
    final target = recommendation.targetCalories;
    final meetsTargets = plan.meetsTargets(target);
    final accent = meetsTargets ? CyberColors.lime : Colors.orange;
    return Column(
      children: [
        CyberCard(
          title: 'Mục tiêu của thực đơn',
          icon: Icons.speed_rounded,
          child: Row(children: [
            Expanded(
                child: MetricTile(
                    label: 'BMR',
                    value: _format(recommendation.bmr),
                    unit: 'kcal')),
            const SizedBox(width: 8),
            Expanded(
                child: MetricTile(
                    label: 'TDEE',
                    value: _format(recommendation.tdee),
                    unit: 'kcal')),
            const SizedBox(width: 8),
            Expanded(
                child: MetricTile(
                    label: 'Mục tiêu', value: _format(target), unit: 'kcal')),
          ]),
        ),
        const SizedBox(height: 14),
        CyberCard(
          title: 'Đối chiếu thực đơn',
          icon: meetsTargets
              ? Icons.check_circle_outline_rounded
              : Icons.info_outline_rounded,
          accent: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  meetsTargets
                      ? 'Trong khoảng mục tiêu'
                      : 'Chưa đạt khoảng mục tiêu',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _Comparison(
                  label: 'Calo',
                  actual: plan.totalCalories,
                  target: target,
                  difference: plan.calorieDifference(target),
                  percent: plan.calorieDeviationPercent(target),
                  unit: 'kcal'),
              const SizedBox(height: 12),
              _Comparison(
                  label: 'Protein',
                  actual: plan.totalProtein,
                  target: plan.proteinTarget,
                  difference: plan.proteinDifference,
                  percent: plan.proteinDeviationPercent,
                  unit: 'g'),
              const SizedBox(height: 10),
              Text(
                  'Mốc đối chiếu: calo ±5%, protein ±10%. '
                  'Thực đơn gợi ý chưa phải lượng bạn đã ăn.',
                  style: TextStyle(color: CyberColors.muted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        CyberCard(
          title: 'Các bữa ăn',
          icon: Icons.ramen_dining_rounded,
          accent: CyberColors.magenta,
          child: Column(
            children: recommendation.plan.meals.entries.map((entry) {
              final meal = entry.value;
              final label = const {
                    'Breakfast': 'Bữa sáng',
                    'Lunch': 'Bữa trưa',
                    'Dinner': 'Bữa tối'
                  }[entry.key] ??
                  entry.key;
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
                    Text('${_format(meal.calories)} kcal • '
                        'P ${_format(meal.protein, 1)} g • '
                        'C ${_format(meal.carbohydrates, 1)} g • '
                        'F ${_format(meal.fat, 1)} g'),
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
    final sign = difference >= 0 ? '+' : '';
    final decimals = unit == 'g' ? 1 : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            '$label: ${_format(actual, decimals)} / ${_format(target, decimals)} $unit',
            style: TextStyle(
                color: CyberColors.text, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
            'Lệch $sign${difference.toStringAsFixed(decimals)} $unit '
            '($sign${percent.toStringAsFixed(1)}%)',
            style: TextStyle(color: CyberColors.muted)),
      ],
    );
  }
}
