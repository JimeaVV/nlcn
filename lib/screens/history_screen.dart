import 'package:flutter/material.dart';
import '../core/cyber_theme.dart';
import '../services/database_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  final db = DatabaseService.instance;
  bool loading = true;
  List<Map<String, dynamic>> meals = [];
  List<Map<String, dynamic>> workouts = [];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final mealRows = await db.getMealHistory();
    final workoutRows = await db.getWorkoutHistory();
    if (!mounted) return;
    setState(() {
      meals = mealRows;
      workouts = workoutRows;
      loading = false;
    });
  }

  String dateText(String raw) {
    final d = DateTime.tryParse(raw)?.toLocal();
    if (d == null) return raw;
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year} ${p(d.hour)}:${p(d.minute)}';
  }

  Future<void> showMeal(Map<String, dynamic> row) async {
    final response = db.decodeJson(row['plan_json'] as String);
    final plan = response['data'] as Map<String, dynamic>;
    final data = plan['meals'] as Map<String, dynamic>;
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CyberColors.surface,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .75,
        maxChildSize: .92,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(18),
          children: [
            Text('SAVED MEAL PLAN',
              style: TextStyle(color: CyberColors.cyan,fontSize: 20,fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            ...data.entries.map((entry) {
              final meal = entry.value as Map<String, dynamic>;
              final items = meal['items'] as List;
              return Card(
                color: CyberColors.surfaceAlt,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(entry.key.toUpperCase(),
                      style: TextStyle(color: CyberColors.magenta,fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    ...items.map((item) {
                      final m = item as Map<String, dynamic>;
                      final prep = '${m['suggested_prep'] ?? ''}'.trim();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Text('• ${m['display_name'] ?? m['name']}'
                          '${prep.isEmpty ? '' : '\n  Prep: $prep'}'),
                      );
                    }),
                  ]),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> showWorkout(Map<String, dynamic> row) async {
    final response = db.decodeJson(row['exercises_json'] as String);
    final items = response['data'] as List;
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CyberColors.surface,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .7,
        maxChildSize: .92,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(18),
          children: [
            Text('SAVED WORKOUT',
              style: TextStyle(color: CyberColors.magenta,fontSize: 20,fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            ...List.generate(items.length, (i) {
              final item = items[i] as Map<String, dynamic>;
              return Card(
                color: CyberColors.surfaceAlt,
                child: ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text('${item['name']}'),
                  subtitle: Text('${item['muscle_group']} • ${item['equipment']} • ${item['estimated_time_mins']} min'),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(child: Text('HISTORY ARCHIVE', style: Theme.of(context).textTheme.headlineSmall)),
            IconButton(
              onPressed: meals.isEmpty && workouts.isEmpty ? null : () async {
                await db.clearAllHistory();
                await refresh();
              },
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ]),
          const SizedBox(height: 16),
          Text('MEAL PLANS', style: TextStyle(color: CyberColors.cyan,fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (meals.isEmpty) const Text('No saved meal plans yet.'),
          ...meals.map((row) => Card(
            child: ListTile(
              onTap: () => showMeal(row),
              leading: Icon(Icons.restaurant_menu_rounded,color: CyberColors.cyan),
              title: Text('${(row['total_calories'] as num).round()} kcal • ${(row['total_protein'] as num).toStringAsFixed(1)}g protein'),
              subtitle: Text(dateText(row['created_at'] as String)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await db.deleteMealPlan(row['id'] as int);
                  await refresh();
                },
              ),
            ),
          )),
          const SizedBox(height: 18),
          Text('WORKOUT PLANS', style: TextStyle(color: CyberColors.magenta,fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (workouts.isEmpty) const Text('No saved workout plans yet.'),
          ...workouts.map((row) => Card(
            child: ListTile(
              onTap: () => showWorkout(row),
              leading: Icon(Icons.fitness_center_rounded,color: CyberColors.magenta),
              title: Text('${row['split']} • ${row['level']}'),
              subtitle: Text('${row['estimated_time']} min • ${dateText(row['created_at'] as String)}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await db.deleteWorkoutPlan(row['id'] as int);
                  await refresh();
                },
              ),
            ),
          )),
        ],
      ),
    );
  }
}
