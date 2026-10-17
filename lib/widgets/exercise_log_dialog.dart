import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../l10n/l10n.dart';
import '../core/number_input.dart';

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
        currentWeight: parseDecimal(weightController.text)!,
        set1Reps: int.parse(set1Controller.text.trim()),
        set2Reps: int.parse(set2Controller.text.trim()),
        set3Reps: int.parse(set3Controller.text.trim()),
        difficulty: difficulty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.logExerciseTitle(widget.exerciseName)),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.progressionModel,
                style: TextStyle(color: CyberColors.muted),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: weightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.currentLoadKg,
                ),
                validator: (value) {
                  final number = parseDecimal(value);
                  if (number == null || number < 0 || number > 1000) {
                    return l10n.currentLoadError;
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
                      label: l10n.setLabel('1'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RepField(
                      controller: set2Controller,
                      label: l10n.setLabel('2'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RepField(
                      controller: set3Controller,
                      label: l10n.setLabel('3'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: difficulty,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.difficulty),
                items: [
                  for (final value in const [
                    'Easy',
                    'Moderate',
                    'Hard',
                    'Failure',
                  ])
                    DropdownMenuItem(
                      value: value,
                      child: Text(l10n.difficultyLabel(value)),
                    ),
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
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: submit, child: Text(l10n.calculate)),
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
        final number = int.tryParse(value?.trim() ?? '');
        if (number == null || number < 0 || number > 30) {
          return context.l10n.repsRange;
        }
        return null;
      },
    );
  }
}
