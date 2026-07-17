import 'package:flutter/material.dart';
import '../core/cyber_theme.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../widgets/cyber_card.dart';
import '../widgets/metric_tile.dart';
import '../widgets/neon_button.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key, required this.api});
  final ApiService api;

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final formKey = GlobalKey<FormState>();
  final timeController = TextEditingController(text: '45');
  String split = 'Push';
  String level = 'Beginner';
  bool loading = false;
  String? error;
  Map<String, dynamic>? result;

  @override
  void dispose() {
    timeController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    if (!formKey.currentState!.validate()) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await widget.api.recommendWorkout(
        split: split,
        level: level,
        minutes: int.parse(timeController.text.trim()),
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

  Future<void> saveWorkout() async {
    if (result == null) return;
    await DatabaseService.instance.saveWorkoutPlan(
      split: split,
      level: level,
      response: result!,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Workout plan saved.')),
    );
  }

  Future<void> logExercise(String exerciseName) async {
    final weightController = TextEditingController();
    final set1Controller = TextEditingController(text: '12');
    final set2Controller = TextEditingController(text: '12');
    final set3Controller = TextEditingController(text: '12');
    String difficulty = 'Moderate';
    final logFormKey = GlobalKey<FormState>();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Log $exerciseName'),
              content: SingleChildScrollView(
                child: Form(
                  key: logFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Progression model: 3 sets in the 8–12 rep range.',
                        style: TextStyle(color: CyberColors.muted),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: weightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Current weight (kg)',
                        ),
                        validator: (value) {
                          final number = double.tryParse(value ?? '');
                          if (number == null || number < 0) {
                            return 'Enter a valid weight.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _RepField(
                              controller: set1Controller,
                              label: 'Set 1',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _RepField(
                              controller: set2Controller,
                              label: 'Set 2',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _RepField(
                              controller: set3Controller,
                              label: 'Set 3',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: difficulty,
                        decoration: const InputDecoration(
                          labelText: 'Difficulty',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Easy', child: Text('Easy')),
                          DropdownMenuItem(
                            value: 'Moderate',
                            child: Text('Moderate'),
                          ),
                          DropdownMenuItem(value: 'Hard', child: Text('Hard')),
                          DropdownMenuItem(
                            value: 'Failure',
                            child: Text('Failure'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => difficulty = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (logFormKey.currentState!.validate()) {
                      Navigator.pop(dialogContext, true);
                    }
                  },
                  child: const Text('Calculate'),
                ),
              ],
            );
          },
        );
      },
    );

    if (submitted != true) {
      weightController.dispose();
      set1Controller.dispose();
      set2Controller.dispose();
      set3Controller.dispose();
      return;
    }

    try {
      final currentWeight = double.parse(weightController.text.trim());
      final set1 = int.parse(set1Controller.text.trim());
      final set2 = int.parse(set2Controller.text.trim());
      final set3 = int.parse(set3Controller.text.trim());

      final recommendation = await widget.api.recommendProgressiveOverload(
        exerciseName: exerciseName,
        currentWeight: currentWeight,
        set1Reps: set1,
        set2Reps: set2,
        set3Reps: set3,
        difficulty: difficulty,
      );

      await DatabaseService.instance.saveWorkoutLog(
        exerciseName: exerciseName,
        currentWeight: currentWeight,
        set1Reps: set1,
        set2Reps: set2,
        set3Reps: set3,
        difficulty: difficulty,
        recommendation: recommendation,
      );

      if (!mounted) return;
      final data = recommendation['data'] as Map<String, dynamic>;

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Next-session recommendation'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data['next_weight']} kg • 3 sets • '
                  'target ${data['next_rep_target']} reps',
                  style: const TextStyle(
                    color: CyberColors.cyan,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text('${data['message']}'),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      weightController.dispose();
      set1Controller.dispose();
      set2Controller.dispose();
      set3Controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          Text(
            'WORKOUT PROTOCOL',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 18),
          CyberCard(
            title: 'Training setup',
            icon: Icons.tune_rounded,
            accent: CyberColors.magenta,
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: split,
                    decoration: const InputDecoration(
                      labelText: 'Workout split',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Push', child: Text('Push')),
                      DropdownMenuItem(value: 'Pull', child: Text('Pull')),
                      DropdownMenuItem(value: 'Legs', child: Text('Legs')),
                      DropdownMenuItem(value: 'Core', child: Text('Core')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => split = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: level,
                    decoration: const InputDecoration(
                      labelText: 'Experience level',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Beginner',
                        child: Text('Beginner • max 5 exercises'),
                      ),
                      DropdownMenuItem(
                        value: 'Intermediate',
                        child: Text('Intermediate • max 7 exercises'),
                      ),
                      DropdownMenuItem(
                        value: 'Pro',
                        child: Text('Pro • max 9 exercises'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => level = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: timeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Available time (minutes)',
                    ),
                    validator: (value) {
                      final number = int.tryParse(value ?? '');
                      if (number == null || number < 15 || number > 180) {
                        return 'Use 15–180 minutes.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  NeonButton(
                    label: 'GENERATE WORKOUT',
                    icon: Icons.bolt_rounded,
                    color: CyberColors.magenta,
                    loading: loading,
                    onPressed: submit,
                  ),
                ],
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: const TextStyle(color: CyberColors.danger),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 16),
            _WorkoutResult(
              data: result!,
              onLogExercise: logExercise,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: saveWorkout,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('SAVE WORKOUT PLAN'),
            ),
          ],
        ],
      ),
    );
  }
}

class _RepField extends StatelessWidget {
  const _RepField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final number = int.tryParse(value ?? '');
        if (number == null || number < 0 || number > 30) return '0–30';
        return null;
      },
    );
  }
}

class _WorkoutResult extends StatelessWidget {
  const _WorkoutResult({
    required this.data,
    required this.onLogExercise,
  });

  final Map<String, dynamic> data;
  final Future<void> Function(String exerciseName) onLogExercise;

  int i(dynamic value) =>
      value is num ? value.round() : int.tryParse('$value') ?? 0;

  @override
  Widget build(BuildContext context) {
    final exercises = data['data'] is List ? data['data'] as List : const [];
    final note = '${data['note'] ?? ''}'.trim();

    return Column(
      children: [
        CyberCard(
          title: 'Session summary',
          accent: CyberColors.lime,
          child: Column(
            children: [
              Row(
                children: [
                  MetricTile(
                    label: 'Target',
                    value: '${i(data['target_time'])}',
                    unit: 'min',
                  ),
                  const SizedBox(width: 8),
                  MetricTile(
                    label: 'Estimated',
                    value: '${i(data['estimated_time'])}',
                    unit: 'min',
                  ),
                  const SizedBox(width: 8),
                  MetricTile(
                    label: 'Exercises',
                    value: '${i(data['total_exercises'])}',
                  ),
                ],
              ),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  note,
                  style: const TextStyle(color: CyberColors.muted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        CyberCard(
          title: 'Exercise sequence',
          accent: CyberColors.cyan,
          child: Column(
            children: List.generate(exercises.length, (index) {
              final item = exercises[index] as Map<String, dynamic>;
              final exerciseName = '${item['name']}';
              return Card(
                color: CyberColors.surfaceAlt,
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(exerciseName),
                    subtitle: Text(
                      '${item['muscle_group']} • ${item['equipment']} • '
                      '${item['estimated_time_mins']} min',
                    ),
                    trailing: IconButton(
                      tooltip: 'Log result',
                      onPressed: () => onLogExercise(exerciseName),
                      icon: const Icon(
                        Icons.trending_up_rounded,
                        color: CyberColors.lime,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
