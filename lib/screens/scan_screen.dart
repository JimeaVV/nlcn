import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../l10n/l10n.dart';
import '../models/food_log_entry.dart';
import '../services/database_service.dart';
import '../services/dataset_repository.dart';
import '../widgets/food_log_sheet.dart';

/// Entry point of the Scan action. Until the on-device model ships it offers
/// manual logging, which stays as the fallback when recognition is wrong.
/// Pops with `true` once something was added to today's diary.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.datasets, this.database});

  final DatasetRepository datasets;
  final DatabaseService? database;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _saving = false;

  Future<void> _logManually() async {
    if (_saving) return;
    List<Map<String, dynamic>> foods;
    try {
      foods = (await widget.datasets.load()).foods;
    } catch (_) {
      foods = const [];
    }
    if (!mounted) return;
    final entry = await showModalBottomSheet<FoodLogEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CyberColors.surface,
      builder: (_) => FoodLogSheet(foods: foods, date: DateTime.now()),
    );
    if (entry == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await (widget.database ?? DatabaseService.instance)
          .addFoodLogEntries([entry]);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.diarySaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scanTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        CyberColors.cyan.withValues(alpha: 0.25),
                        CyberColors.magenta.withValues(alpha: 0.25),
                      ],
                    ),
                  ),
                  child: Icon(Icons.photo_camera_rounded,
                      size: 52, color: CyberColors.cyan),
                ),
                const SizedBox(height: 20),
                Text(l10n.scanTitle,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 10),
                Text(
                  l10n.scanComingSoon,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: CyberColors.muted),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const ValueKey('scan-manual'),
                  onPressed: _saving ? null : _logManually,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: Text(l10n.scanManual),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
