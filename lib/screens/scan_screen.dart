import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/cyber_theme.dart';
import '../l10n/l10n.dart';
import '../models/food_log_entry.dart';
import '../services/database_service.dart';
import '../services/dataset_repository.dart';
import '../services/food_recognizer.dart';
import '../services/vn_food_repository.dart';
import '../widgets/food_log_sheet.dart';
import '../widgets/scan_button_face.dart';
import 'scan_result_screen.dart';

/// Returns the path of a photo from [source], or null when cancelled.
typedef ImagePathPicker = Future<String?> Function(ImageSource source);

Future<String?> _pickWithImagePicker(ImageSource source) async {
  // Recognition only needs a modest resolution; smaller files are faster.
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1280,
    maxHeight: 1280,
    imageQuality: 85,
  );
  return file?.path;
}

/// Entry point of the Scan action: take or choose a photo of one plate,
/// or log food manually. Pops with `true` once something was logged.
class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    required this.datasets,
    this.vnFood,
    this.recognizer = const NoModelRecognizer(),
    this.pickImage = _pickWithImagePicker,
    this.database,
  });

  final DatasetRepository datasets;
  final VnFoodRepository? vnFood;
  final FoodRecognizer recognizer;
  final ImagePathPicker pickImage;
  final DatabaseService? database;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late final VnFoodRepository _vnFood = widget.vnFood ?? VnFoodRepository();
  bool _busy = false;

  void _message(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _scan(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      String? path;
      try {
        path = await widget.pickImage(source);
      } catch (_) {
        if (mounted) _message(context.l10n.scanPickFailed);
        return;
      }
      if (path == null || !mounted) return;
      final data = await _vnFood.load();
      if (!mounted) return;
      final logged = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ScanResultScreen(
            imagePath: path!,
            data: data,
            recognizer: widget.recognizer,
            database: widget.database,
          ),
        ),
      );
      if (logged == true && mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) _message(context.l10n.scanDataFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logManually() async {
    if (_busy) return;
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
    setState(() => _busy = true);
    try {
      await (widget.database ?? DatabaseService.instance)
          .addFoodLogEntries([entry]);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _message(context.l10n.diarySaveFailed);
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ScanButtonFace(style: CyberColors.style, size: 104),
                ),
                const SizedBox(height: 20),
                Text(l10n.scanTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 10),
                Text(
                  l10n.scanSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: CyberColors.muted),
                ),
                if (!widget.recognizer.isAvailable) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.scanModelPending,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: CyberColors.muted, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const ValueKey('scan-camera'),
                  onPressed: _busy ? null : () => _scan(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: Text(l10n.scanTakePhoto),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const ValueKey('scan-gallery'),
                  onPressed: _busy ? null : () => _scan(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(l10n.scanPickGallery),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  key: const ValueKey('scan-manual'),
                  onPressed: _busy ? null : _logManually,
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
