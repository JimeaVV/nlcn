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
    setState(() { loading = true; error = null; });
    try {
      final response = await widget.api.recommendWorkout(
        split: split, level: level, minutes: int.parse(timeController.text.trim()));
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
      split: split, level: level, response: result!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Workout plan saved.')));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: ListView(
      padding: const EdgeInsets.fromLTRB(16,10,16,28),
      children: [
        Text('WORKOUT PROTOCOL',style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 18),
        CyberCard(
          title: 'Training setup',
          icon: Icons.tune_rounded,
          accent: CyberColors.magenta,
          child: Form(
            key: formKey,
            child: Column(children: [
              DropdownButtonFormField<String>(
                value: split,
                decoration: const InputDecoration(labelText: 'Workout split'),
                items: const [
                  DropdownMenuItem(value:'Push',child:Text('Push')),
                  DropdownMenuItem(value:'Pull',child:Text('Pull')),
                  DropdownMenuItem(value:'Legs',child:Text('Legs')),
                  DropdownMenuItem(value:'Core',child:Text('Core')),
                ],
                onChanged: (v) { if (v != null) setState(() => split = v); },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: level,
                decoration: const InputDecoration(labelText: 'Experience level'),
                items: const [
                  DropdownMenuItem(value:'Beginner',child:Text('Beginner')),
                  DropdownMenuItem(value:'Intermediate',child:Text('Intermediate')),
                  DropdownMenuItem(value:'Pro',child:Text('Pro')),
                ],
                onChanged: (v) { if (v != null) setState(() => level = v); },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: timeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText:'Available time (minutes)'),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 15 || n > 180) return 'Use 15–180 minutes.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              NeonButton(
                label:'GENERATE WORKOUT',
                icon:Icons.bolt_rounded,
                color:CyberColors.magenta,
                loading:loading,
                onPressed:submit,
              ),
            ]),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!,style: TextStyle(color:CyberColors.danger)),
        ],
        if (result != null) ...[
          const SizedBox(height: 16),
          _WorkoutResult(data: result!),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: saveWorkout,
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('SAVE WORKOUT PLAN'),
          ),
        ],
      ],
    ));
  }
}

class _WorkoutResult extends StatelessWidget {
  const _WorkoutResult({required this.data});
  final Map<String,dynamic> data;
  int i(dynamic v) => v is num ? v.round() : int.tryParse('$v') ?? 0;

  @override
  Widget build(BuildContext context) {
    final exercises = data['data'] is List ? data['data'] as List : const [];
    return Column(children: [
      CyberCard(
        title:'Session summary',
        accent:CyberColors.lime,
        child:Row(children:[
          MetricTile(label:'Target',value:'${i(data['target_time'])}',unit:'min'),
          const SizedBox(width:8),
          MetricTile(label:'Estimated',value:'${i(data['estimated_time'])}',unit:'min'),
          const SizedBox(width:8),
          MetricTile(label:'Exercises',value:'${i(data['total_exercises'])}'),
        ]),
      ),
      const SizedBox(height:14),
      CyberCard(
        title:'Exercise sequence',
        accent:CyberColors.cyan,
        child:Column(children: List.generate(exercises.length,(index){
          final item = exercises[index] as Map<String,dynamic>;
          return ListTile(
            leading: CircleAvatar(child: Text('${index+1}')),
            title: Text('${item['name']}'),
            subtitle: Text('${item['muscle_group']} • ${item['equipment']} • ${item['estimated_time_mins']} min'),
          );
        })),
      ),
    ]);
  }
}
