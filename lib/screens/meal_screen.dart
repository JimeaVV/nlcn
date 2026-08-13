import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../models/recommendation_models.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../widgets/cyber_card.dart';
import '../widgets/error_box.dart';
import '../widgets/meal_result.dart';
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
  bool saving = false;
  String? error;
  DietRecommendation? result;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    ageController.dispose();
    weightController.dispose();
    heightController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await DatabaseService.instance.getProfile();
      if (profile == null || !mounted) return;
      setState(() {
        ageController.text = '${profile['age']}';
        weightController.text = '${profile['weight']}';
        heightController.text = '${profile['height']}';
        gender = '${profile['gender']}';
        activityLevel = (profile['activity_level'] as num).toDouble();
      });
    } catch (_) {
      if (mounted) setState(() => error = 'Could not load the saved profile.');
    }
  }

  Future<void> _saveMealPlan() async {
    if (result == null || saving) return;
    setState(() => saving = true);
    try {
      await DatabaseService.instance.saveMealPlan(result!);
      if (!mounted) return;
      _showMessage('Meal plan saved.');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Could not save the meal plan.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _positiveNumber(String? value, String name) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null) return 'Enter a valid $name.';
    if (number <= 0) return '$name must be greater than 0.';
    return null;
  }

  String? _ageValidator(String? value) {
    final age = int.tryParse(value?.trim() ?? '');
    if (age == null) return 'Enter a whole-number age.';
    if (age < 13 || age > 100) return 'Use an age from 13 to 100.';
    return null;
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    if (!formKey.currentState!.validate()) return;

    final age = int.parse(ageController.text.trim());
    final weight = double.parse(weightController.text.trim());
    final height = double.parse(heightController.text.trim());

    setState(() {
      loading = true;
      error = null;
      result = null;
    });

    try {
      final response = await widget.api.recommendDiet(
        age: age,
        gender: gender,
        weight: weight,
        height: height,
        activityLevel: activityLevel,
      );
      await DatabaseService.instance.saveProfile(
        age: age,
        gender: gender,
        height: height,
        weight: weight,
        activityLevel: activityLevel,
      );
      if (mounted) setState(() => result = response);
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not save the local user profile.');
      }
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
                          validator: _ageValidator,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(gender),
                          initialValue: gender,
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Height (cm)',
                      prefixIcon: Icon(Icons.height_rounded),
                    ),
                    validator: (value) => _positiveNumber(value, 'height'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      prefixIcon: Icon(Icons.monitor_weight_outlined),
                    ),
                    validator: (value) => _positiveNumber(value, 'weight'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<double>(
                    key: ValueKey(activityLevel),
                    initialValue: activityLevel,
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
                      DropdownMenuItem(value: 1.9, child: Text('Extra active')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => activityLevel = value);
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
            ErrorBox(message: error!),
          ],
          if (result != null) ...[
            const SizedBox(height: 16),
            MealResult(recommendation: result!),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: saving ? null : _saveMealPlan,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(saving ? 'SAVING...' : 'SAVE MEAL PLAN'),
            ),
          ],
        ],
      ),
    );
  }
}
