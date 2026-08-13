import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';

class ExerciseLogInput {
  const ExerciseLogInput({
    required this.currentWeight,
    required this.set1Reps,
    required this.set2Reps,
    required this.set3Reps,
    required this.difficulty,
  });

  final double currentWeight;
  final int set1Reps;
  final int set2Reps;
  final int set3Reps;
  final String difficulty;
}

class ExerciseLogDialog extends StatefulWidget {
  const ExerciseLogDialog({super.key, required this.exerciseName});

  final String exerciseName;

  @override
  State<ExerciseLogDialog> createState() => _ExerciseLogDialogState();
}

class _ExerciseLogDialogState extends State<ExerciseLogDialog> {
  final formKey = GlobalKey<FormState>();
  final weightController = TextEditingController();
  final set1Controller = TextEditingController(text: '12');
  final set2Controller = TextEditingController(text: '12');
  final set3Controller = TextEditingController(text: '12');
  String difficulty = 'Moderate';

  @override
  void dispose() {
    weightController.dispose();
    set1Controller.dispose();
    set2Controller.dispose();
    set3Controller.dispose();
    super.dispose();
  }

  void submit() {
    if (!formKey.currentState!.validate()) return;

    Navigator.pop(
      context,
      ExerciseLogInput(
        currentWeight: double.parse(weightController.text.trim()),
        set1Reps: int.parse(set1Controller.text.trim()),
        set2Reps: int.parse(set2Controller.text.trim()),
        set3Reps: int.parse(set3Controller.text.trim()),
        difficulty: difficulty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Log ${widget.exerciseName}'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
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
                initialValue: difficulty,
                decoration: const InputDecoration(labelText: 'Difficulty'),
                items: const [
                  DropdownMenuItem(value: 'Easy', child: Text('Easy')),
                  DropdownMenuItem(value: 'Moderate', child: Text('Moderate')),
                  DropdownMenuItem(value: 'Hard', child: Text('Hard')),
                  DropdownMenuItem(value: 'Failure', child: Text('Failure')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => difficulty = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: submit, child: const Text('Calculate')),
      ],
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
