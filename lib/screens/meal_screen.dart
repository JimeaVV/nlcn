import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../widgets/cyber_card.dart';
import '../widgets/metric_tile.dart';
import '../widgets/neon_button.dart';

class MealScreen extends StatefulWidget {
  const MealScreen({super.key, required this.api});

  final ApiService api;

  @override
  State<MealScreen> createState() => _MealScreenState();
}

class _MealScreenState extends State<MealScreen> {
  final formKey = GlobalKey<FormState>();
  final ageController = TextEditingController(text: '21');
  final weightController = TextEditingController(text: '70');
  final heightController = TextEditingController(text: '175');

  String gender = 'male';
  double activityLevel = 1.55;
  bool loading = false;
  String? error;
  Map<String, dynamic>? result;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await DatabaseService.instance.getProfile();
    if (profile == null || !mounted) return;
    setState(() {
      ageController.text = '${profile['age']}';
      weightController.text = '${profile['weight']}';
      heightController.text = '${profile['height']}';
      gender = '${profile['gender']}';
      activityLevel = (profile['activity_level'] as num).toDouble();
    });
  }

  Future<void> _saveMealPlan() async {
    if (result == null) return;
    await DatabaseService.instance.saveMealPlan(result!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Meal plan saved.')),
    );
  }

  @override
  void dispose() {
    ageController.dispose();
    weightController.dispose();
    heightController.dispose();
    super.dispose();
  }

  String? _positiveNumber(String? value, String name) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null) return 'Enter a valid $name.';
    if (number <= 0) return '$name must be greater than 0.';
    return null;
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    if (!formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await widget.api.recommendDiet(
        age: int.parse(ageController.text.trim()),
        gender: gender,
        weight: double.parse(weightController.text.trim()),
        height: double.parse(heightController.text.trim()),
        activityLevel: activityLevel,
      );

      await DatabaseService.instance.saveProfile(
        age: int.parse(ageController.text.trim()),
        gender: gender,
        height: double.parse(heightController.text.trim()),
        weight: double.parse(weightController.text.trim()),
        activityLevel: activityLevel,
      );
      if (!mounted) return;
      setState(() => result = response);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          Text(
            'MEAL PROTOCOL',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your body metrics to calculate BMR, TDEE and a suggested daily meal plan.',
            style: TextStyle(color: CyberColors.muted),
          ),
          const SizedBox(height: 18),
          CyberCard(
            title: 'Personal data',
            icon: Icons.person_outline_rounded,
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: ageController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Age',
                            prefixIcon: Icon(Icons.cake_outlined),
                          ),
                          validator: (value) {
                            final base = _positiveNumber(value, 'age');
                            if (base != null) return base;
                            final age = int.parse(value!);
                            if (age < 13 || age > 100) {
                              return 'Use an age from 13 to 100.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: gender,
                          decoration: const InputDecoration(
                            labelText: 'Gender',
                            prefixIcon: Icon(Icons.wc_rounded),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'male',
                              child: Text('Male'),
                            ),
                            DropdownMenuItem(
                              value: 'female',
                              child: Text('Female'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => gender = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: heightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Height (cm)',
                      prefixIcon: Icon(Icons.height_rounded),
                    ),
                    validator: (value) => _positiveNumber(value, 'height'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: weightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      prefixIcon: Icon(Icons.monitor_weight_outlined),
                    ),
                    validator: (value) => _positiveNumber(value, 'weight'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<double>(
                    value: activityLevel,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Activity level',
                      prefixIcon: Icon(Icons.directions_run_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 1.2,
                        child: Text('Sedentary — little exercise'),
                      ),
                      DropdownMenuItem(
                        value: 1.375,
                        child: Text('Light — 1–3 days/week'),
                      ),
                      DropdownMenuItem(
                        value: 1.55,
                        child: Text('Moderate — 3–5 days/week'),
                      ),
                      DropdownMenuItem(
                        value: 1.725,
                        child: Text('Very active — 6–7 days/week'),
                      ),
                      DropdownMenuItem(
                        value: 1.9,
                        child: Text('Extra active'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => activityLevel = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  NeonButton(
                    label: 'CALCULATE & RECOMMEND',
                    icon: Icons.auto_awesome_rounded,
                    loading: loading,
                    onPressed: submit,
                  ),
                ],
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 14),
            _ErrorBox(message: error!),
          ],
          if (result != null) ...[
            const SizedBox(height: 16),
            _DietResult(data: result!),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saveMealPlan,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('SAVE MEAL PLAN'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DietResult extends StatelessWidget {
  const _DietResult({required this.data});

  final Map<String, dynamic> data;

  num _num(dynamic value) => value is num ? value : num.tryParse('$value') ?? 0;

  @override
  Widget build(BuildContext context) {
    final plan = data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    final meals = plan['meals'] is Map<String, dynamic>
        ? plan['meals'] as Map<String, dynamic>
        : <String, dynamic>{};

    return Column(
      children: [
        CyberCard(
          title: 'Daily targets',
          icon: Icons.speed_rounded,
          accent: CyberColors.lime,
          child: Row(
            children: [
              MetricTile(label: 'BMR', value: '${_num(data['bmr']).round()}', unit: 'kcal'),
              const SizedBox(width: 8),
              MetricTile(label: 'TDEE', value: '${_num(data['tdee']).round()}', unit: 'kcal'),
              const SizedBox(width: 8),
              MetricTile(
                label: 'Target',
                value: '${_num(data['target_calories']).round()}',
                unit: 'kcal',
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
                    final meal = entry.value is Map<String, dynamic>
                        ? entry.value as Map<String, dynamic>
                        : <String, dynamic>{};
                    final items = meal['items'] is List
                        ? meal['items'] as List
                        : const [];

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
                              final map = item is Map<String, dynamic>
                                  ? item
                                  : <String, dynamic>{};
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Text(
                                  '• ${map['display_name'] ?? map['name'] ?? 'Food item'}',
                                  style: TextStyle(
                                    color: CyberColors.text,
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              children: [
                                _Chip('Cal ${_num(meal['calo']).round()}'),
                                _Chip('P ${_num(meal['protein']).toStringAsFixed(1)}g'),
                                _Chip('C ${_num(meal['carb']).toStringAsFixed(1)}g'),
                                _Chip('F ${_num(meal['fat']).toStringAsFixed(1)}g'),
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

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFF344665)),
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

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CyberColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CyberColors.danger),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: CyberColors.danger),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
