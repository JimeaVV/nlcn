import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../models/recommendation_models.dart';
import 'cyber_card.dart';
import 'metric_tile.dart';

String _formatWholeNumber(int value) {
  return value.toString().replaceAllMapped(
        RegExp(r'(?<=\d)(?=(\d{3})+$)'),
        (_) => ',',
      );
}

class MealResult extends StatelessWidget {
  const MealResult({super.key, required this.recommendation});

  final DietRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final plan = recommendation.plan;
    final meals = plan.meals;

    return Column(
      children: [
        CyberCard(
          title: 'Daily targets',
          icon: Icons.speed_rounded,
          accent: CyberColors.lime,
          child: Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: 'BMR',
                  value: _formatWholeNumber(recommendation.bmr.round()),
                  unit: 'kcal',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  label: 'TDEE',
                  value: _formatWholeNumber(recommendation.tdee.round()),
                  unit: 'kcal',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  label: 'Target',
                  value: _formatWholeNumber(
                    recommendation.targetCalories.round(),
                  ),
                  unit: 'kcal',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        CyberCard(
          title: 'Recommended meals',
          icon: Icons.ramen_dining_rounded,
          accent: CyberColors.magenta,
          child: meals.isEmpty
              ? const Text('No meal data returned.')
              : Column(
                  children: meals.entries.map((entry) {
                    final meal = entry.value;
                    final items = meal.items;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: CyberColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key.toUpperCase(),
                              style: TextStyle(
                                color: CyberColors.magenta,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...items.map((item) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Text(
                                  '• ${item.displayName}',
                                  style: TextStyle(color: CyberColors.text),
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              children: [
                                _MetricChip(
                                  'Cal ${meal.calories.round()}',
                                ),
                                _MetricChip(
                                  'P ${meal.protein.toStringAsFixed(1)}g',
                                ),
                                _MetricChip(
                                  'C ${meal.carbohydrates.toStringAsFixed(1)}g',
                                ),
                                _MetricChip(
                                  'F ${meal.fat.toStringAsFixed(1)}g',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CyberColors.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: CyberColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
