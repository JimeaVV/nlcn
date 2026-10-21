import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../models/food_log_entry.dart';
import 'database_service.dart';

/// Saves all data to a JSON file the user shares or keeps (Drive, Zalo,
/// Files…), and restores it. Nothing is uploaded by the app itself.
class BackupService {
  const BackupService();

  /// optifit_backup_2026-10-21.json
  static String fileName(DateTime now) =>
      'optifit_backup_${diaryDateKey(now)}.json';

  Future<void> export(DatabaseService database) async {
    final backup = await database.exportBackup();
    final bytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent(' ').convert(backup)));
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'application/json')],
      fileNameOverrides: [fileName(DateTime.now())],
    ));
  }

  /// Lets the user pick a backup file; null when they cancel.
  Future<Map<String, dynamic>?> pick() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (files.isEmpty) return null;
    return parse(await files.first.readAsBytes());
  }

  /// Throws [FormatException] for anything but a JSON object.
  static Map<String, dynamic> parse(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Not an OptiFit backup.');
    }
    return decoded;
  }
}
