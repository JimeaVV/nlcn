import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/text_search.dart';

/// Keeps the user's own scan photos with the dish they confirmed, so a later
/// training run learns the food they actually eat (docs/MODEL_CONTRACT.md §5).
///
/// Off by default. Photos stay on the phone, shrunk to [maxSide] px, under
/// `<app support>/training_photos/<label>/`, listed in `index.csv`; they
/// leave it only when the user exports the zip.
class PhotoCollector extends ChangeNotifier {
  PhotoCollector({Future<Directory> Function()? root})
      : _root = root ?? _defaultRoot;

  static final instance = PhotoCollector();

  static Future<Directory> _defaultRoot() async => Directory(
      '${(await getApplicationSupportDirectory()).path}/training_photos');

  /// The long side of a kept photo: the notebook shrinks to 384 on the
  /// short side, so this leaves room for its random crops.
  static const maxSide = 640;
  static const _enabledKey = 'collect_photos';

  final Future<Directory> Function() _root;
  bool _enabled = false;
  bool _loaded = false;

  bool get enabled => _enabled;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      _enabled =
          (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? false;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      await (await SharedPreferences.getInstance()).setBool(_enabledKey, value);
    } catch (_) {}
    notifyListeners();
  }

  /// A dish code or `single_<component>` as it is; a food the app does not
  /// know becomes `new_<name>`, e.g. "Yến mạch" → `new_yen_mach`.
  static String labelForNewFood(String name) {
    final slug = foldForSearch(name)
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return 'new_${slug.isEmpty ? 'food' : slug}';
  }

  /// Saves [photoPath] shrunk under [label] when collecting is on. [name] is
  /// what the user saw, [guess] and [confidence] what the model said: photos
  /// it got wrong are the most useful ones to train on.
  Future<void> save(
    String photoPath, {
    required String label,
    required String name,
    String? guess,
    double? confidence,
  }) async {
    if (!_enabled) return;
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(label)) {
      throw ArgumentError('Labels are lower-case codes: $label');
    }
    final bytes = await compute(_shrink, await File(photoPath).readAsBytes());
    if (bytes == null) return;
    final root = await _root();
    final folder = Directory('${root.path}/$label');
    await folder.create(recursive: true);
    final now = DateTime.now();
    final file = '$label/${now.millisecondsSinceEpoch}.jpg';
    await File('${root.path}/$file').writeAsBytes(bytes);
    final index = File('${root.path}/index.csv');
    if (!await index.exists()) {
      await index.writeAsString('file,label,name,model_guess,model_confidence,'
          'saved_at\n');
    }
    String cell(String value) => '"${value.replaceAll('"', '""')}"';
    final row = [
      file,
      label,
      cell(name),
      guess ?? '',
      confidence?.toStringAsFixed(3) ?? '',
      now.toIso8601String(),
    ].join(',');
    await index.writeAsString('$row\n', mode: FileMode.append);
    notifyListeners();
  }

  /// How many photos are kept, and their size in bytes.
  Future<({int photos, int bytes})> stats() async {
    try {
      final root = await _root();
      if (!await root.exists()) return (photos: 0, bytes: 0);
      var photos = 0, bytes = 0;
      await for (final entity in root.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.jpg')) {
          photos++;
          bytes += await entity.length();
        }
      }
      return (photos: photos, bytes: bytes);
    } catch (_) {
      return (photos: 0, bytes: 0);
    }
  }

  /// All kept photos and index.csv in one zip in the temporary folder; null
  /// when there is nothing to export.
  Future<File?> exportZip(String zipPath) async {
    final root = await _root();
    if ((await stats()).photos == 0) return null;
    final encoder = ZipFileEncoder()..create(zipPath);
    await encoder.addDirectory(root, includeDirName: false);
    await encoder.close();
    return File(zipPath);
  }

  /// Deletes every kept photo.
  Future<void> clear() async {
    final root = await _root();
    if (await root.exists()) await root.delete(recursive: true);
    notifyListeners();
  }
}

/// Upright, at most [PhotoCollector.maxSide] px on the long side, JPEG 85.
Uint8List? _shrink(Uint8List encoded) {
  final decoded = img.decodeImage(encoded);
  if (decoded == null) return null;
  var photo = img.bakeOrientation(decoded);
  final longest = photo.width > photo.height ? photo.width : photo.height;
  if (longest > PhotoCollector.maxSide) {
    photo = photo.width >= photo.height
        ? img.copyResize(photo, width: PhotoCollector.maxSide)
        : img.copyResize(photo, height: PhotoCollector.maxSide);
  }
  return img.encodeJpg(photo, quality: 85);
}
