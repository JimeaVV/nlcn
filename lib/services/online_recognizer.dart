import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'tflite_food_recognizer.dart' show modelFolder;

/// The Gemini key, set only in test builds with
/// `flutter build apk --dart-define=GEMINI_API_KEY=...`. Builds without it
/// (CI, release) have no online mode at all.
const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

/// The model, instructions and class descriptions, shared with
/// tool/eval/gemini_compare.py so the app asks what was measured.
const onlineSpecAsset = '$modelFolder/online_classes.json';

/// Gemini Flash-Lite answered in 2.4 s (median) on the test photos; past
/// this the detector's plate is used.
const onlineTimeout = Duration(seconds: 8);

/// The Gemini models a dev test build can use. Only [flashLite] was
/// measured on the test photos (docs/QUA_TRINH_THUC_HIEN.md, 2026-11-02);
/// [flash] is stronger but slower, and its free tier allows 20 photos a day.
enum OnlineModel {
  flashLite('gemini-3.5-flash-lite', onlineTimeout),
  // It thinks before answering; low thinking keeps a scan to seconds.
  flash('gemini-3.8-flash', Duration(seconds: 20), thinkingLevel: 'low');

  const OnlineModel(this.id, this.timeout, {this.thinkingLevel});

  final String id;
  final Duration timeout;
  final String? thinkingLevel;

  static OnlineModel byId(String? id) => values.firstWhere(
      (model) => model.id == id,
      orElse: () => values.first);
}

/// The long side of the photo that is sent.
const onlineMaxSide = 1024;

final _endpoint =
    Uri.parse('https://generativelanguage.googleapis.com/v1beta/interactions');

/// The prompt and answer schema built from [onlineSpecAsset] and the
/// detector classes, exactly as tool/eval/gemini_compare.py builds them.
class OnlineSpec {
  const OnlineSpec({
    required this.model,
    required this.prompt,
    required this.schema,
    required this.classes,
    required this.other,
  });

  factory OnlineSpec.parse(String json, List<String> classes) {
    final spec = jsonDecode(json) as Map<String, dynamic>;
    final other = spec['other'] as Map<String, dynamic>;
    final otherId = other['id'] as String;
    final described = spec['classes'] as Map<String, dynamic>;
    // Exactly the detector's classes, as tool/eval/gemini_compare.py checks.
    final missing = classes.where((code) => !described.containsKey(code));
    final extra = described.keys.where((code) => !classes.contains(code));
    if (missing.isNotEmpty || extra.isNotEmpty) {
      throw FormatException('$onlineSpecAsset does not match the detector '
          'classes: missing ${missing.join(', ')}; extra ${extra.join(', ')}');
    }
    final prompt = [
      for (final line in spec['instructions'] as List)
        (line as String).replaceAll('{other}', otherId),
      for (final code in classes)
        '- $code: ${described[code]['vi']} / ${described[code]['en']}',
      '- $otherId: ${other['vi']} / ${other['en']}',
    ].join('\n');
    return OnlineSpec(
      model: spec['model'] as String,
      prompt: prompt,
      classes: classes,
      other: otherId,
      schema: {
        'type': 'object',
        'properties': {
          'foods': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'class': {
                  'type': 'string',
                  'enum': [...classes, otherId],
                },
                'name': {
                  'type': 'string',
                  'description': 'what the food is, in a few words',
                },
                'grams': {'type': 'number'},
              },
              'required': ['class', 'name', 'grams'],
            },
          },
        },
        'required': ['foods'],
      },
    );
  }

  static Future<OnlineSpec> load(AssetBundle bundle) async => OnlineSpec.parse(
      await bundle.loadString(onlineSpecAsset),
      [
        for (final line
            in (await bundle.loadString('$modelFolder/detector_classes.txt'))
                .split('\n'))
          if (line.trim().isNotEmpty) line.trim(),
      ]);

  final String model;
  final String prompt;
  final Map<String, dynamic> schema;
  final List<String> classes;

  /// The class for food outside [classes].
  final String other;
}

/// One food Gemini named.
class OnlineFood {
  const OnlineFood({required this.code, required this.name, this.grams});

  /// A detector class, or [OnlineSpec.other].
  final String code;

  /// What Gemini called it, in English.
  final String name;

  /// Gemini's guess, not yet checked against weighed food, so the plate
  /// does not use it (docs/CHE_DO_ONLINE.md §3).
  final double? grams;
}

/// What Gemini saw on one photo.
class OnlineScan {
  const OnlineScan({required this.foods, required this.classes});

  final List<OnlineFood> foods;
  final List<String> classes;

  /// The detector classes named, each once, in Gemini's order.
  List<String> get codes => [
        for (final (i, food) in foods.indexed)
          if (classes.contains(food.code) &&
              foods.take(i).every((earlier) => earlier.code != food.code))
            food.code,
      ];

  /// Foods outside the classes: shown by name only, with no nutrition.
  List<String> get otherNames => [
        for (final food in foods)
          if (!classes.contains(food.code) && food.name.isNotEmpty) food.name,
      ];

  /// Reads Gemini's answer: the JSON text of its output, wherever the
  /// response keeps it. Unknown classes count as other food.
  factory OnlineScan.fromResponse(String body, OnlineSpec spec) {
    String? answer(Object? node) {
      if (node is Map) {
        final text = node['text'];
        if (text is String && text.contains('"foods"')) return text;
        node = node.values.toList();
      }
      if (node is List) {
        for (final item in node) {
          final found = answer(item);
          if (found != null) return found;
        }
      }
      return null;
    }

    final text = answer(jsonDecode(body));
    if (text == null) throw const FormatException('No answer in the response');
    final foods = (jsonDecode(text) as Map<String, dynamic>)['foods'] as List;
    return OnlineScan(
      classes: spec.classes,
      foods: [
        for (final food in foods.whereType<Map<String, dynamic>>())
          OnlineFood(
            code: food['class'] is String ? food['class'] as String : '',
            name: food['name'] is String ? (food['name'] as String).trim() : '',
            grams: (food['grams'] as num?)?.toDouble(),
          ),
      ],
    );
  }
}

/// Why no online answer came: the screen then uses the detector's plate.
enum OnlineFailure { offline, timeout, quota, failed }

class OnlineScanException implements Exception {
  const OnlineScanException(this.kind, [this.detail = '']);

  final OnlineFailure kind;
  final String detail;

  @override
  String toString() => 'OnlineScanException(${kind.name}) $detail';
}

typedef OnlinePost = Future<({int status, String body})> Function(
    Uri url, Map<String, String> headers, List<int> body);

/// The photo as sent: upright, at most [onlineMaxSide] px, and re-encoded
/// without EXIF, so no location or camera data leaves the phone.
Uint8List prepareOnlinePhoto(Uint8List encoded) {
  final decoded = img.decodeImage(encoded);
  if (decoded == null) throw const FormatException('Not an image');
  var photo = img.bakeOrientation(decoded);
  if (math.max(photo.width, photo.height) > onlineMaxSide) {
    photo = photo.width >= photo.height
        ? img.copyResize(photo, width: onlineMaxSide)
        : img.copyResize(photo, height: onlineMaxSide);
  }
  photo.exif = img.ExifData();
  return img.encodeJpg(photo, quality: 90);
}

Future<({int status, String body})> _httpPost(
    Uri url, Map<String, String> headers, List<int> body) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client.postUrl(url);
    headers.forEach(request.headers.set);
    request.add(body);
    final response = await request.close();
    return (
      status: response.statusCode,
      body: await response.transform(utf8.decoder).join(),
    );
  } finally {
    client.close(force: true);
  }
}

/// Optional online recognition with Gemini, for test builds only
/// (docs/CHE_DO_ONLINE.md). Off by default; a photo is sent only when the
/// build has a key and the user turned it on after agreeing to send photos.
class OnlineRecognizer extends ChangeNotifier {
  OnlineRecognizer({
    this.apiKey = geminiApiKey,
    OnlinePost? post,
    AssetBundle? bundle,
    OnlineSpec? spec,
    Future<Uint8List> Function(String imagePath)? readPhoto,
    Duration? timeout,
  })  : _timeout = timeout,
        _post = post ?? _httpPost,
        _bundle = bundle,
        _spec = spec == null ? null : Future.value(spec),
        _readPhoto = readPhoto ?? _preparedPhoto;

  static final instance = OnlineRecognizer();

  static Future<Uint8List> _preparedPhoto(String imagePath) async =>
      compute(prepareOnlinePhoto, await File(imagePath).readAsBytes());

  static const _enabledKey = 'online_recognition';
  static const _consentKey = 'online_consent';
  static const _modelKey = 'online_model';

  /// Raised when the consent text changes, so it is asked again.
  static const consentVersion = 1;

  final String apiKey;

  /// How long an answer may take before the detector's plate is used;
  /// the model's own time unless set.
  Duration get timeout => _timeout ?? _model.timeout;
  final Duration? _timeout;
  final OnlinePost _post;
  final AssetBundle? _bundle;
  final Future<Uint8List> Function(String) _readPhoto;
  Future<OnlineSpec>? _spec;
  bool _enabled = false;
  bool _consented = false;
  bool _loaded = false;
  OnlineModel _model = OnlineModel.values.first;

  /// The model scans are sent to; the measured one until the user picks.
  OnlineModel get model => _model;

  /// False in builds without a key: the settings card is hidden.
  bool get available => apiKey.isNotEmpty;

  bool get consented => _consented;

  /// True when scans may send their photo.
  bool get enabled => available && _enabled && _consented;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? false;
      _consented = (prefs.getInt(_consentKey) ?? 0) >= consentVersion;
      _model = OnlineModel.byId(prefs.getString(_modelKey));
    } catch (error) {
      debugPrint('Online settings not read: $error');
    }
    notifyListeners();
  }

  /// Turning it on needs [consent] true the first time: the user agreed in
  /// the dialog that explains what is sent.
  Future<void> setEnabled(bool value, {bool consent = false}) async {
    if (value && !_consented && !consent) return;
    _enabled = value;
    if (consent) _consented = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
      if (consent) await prefs.setInt(_consentKey, consentVersion);
    } catch (error) {
      debugPrint('Online settings not saved: $error');
    }
  }

  Future<void> setModel(OnlineModel model) async {
    if (model == _model) return;
    _model = model;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modelKey, model.id);
    } catch (error) {
      debugPrint('Online settings not saved: $error');
    }
  }

  /// What Gemini sees on the photo. Throws [OnlineScanException]; never
  /// called unless [enabled].
  Future<OnlineScan> recognize(String imagePath) async {
    if (!enabled) throw const OnlineScanException(OnlineFailure.failed, 'off');
    final OnlineSpec spec;
    final Uint8List photo;
    try {
      spec = await (_spec ??= OnlineSpec.load(_bundle ?? rootBundle));
      photo = await _readPhoto(imagePath);
    } catch (error) {
      _spec = null;
      throw OnlineScanException(OnlineFailure.failed, '$error');
    }
    final model = _model;
    final body = utf8.encode(jsonEncode({
      'model': model.id,
      'input': [
        {'type': 'text', 'text': spec.prompt},
        {'type': 'image', 'data': base64Encode(photo), 'mime_type': 'image/jpeg'},
      ],
      'response_format': {
        'type': 'text',
        'mime_type': 'application/json',
        'schema': spec.schema,
      },
      'generation_config': {
        'seed': 0,
        if (model.thinkingLevel case final level?) 'thinking_level': level,
      },
      'store': false,
    }));
    final ({int status, String body}) response;
    try {
      response = await _post(_endpoint,
              {'Content-Type': 'application/json', 'x-goog-api-key': apiKey}, body)
          .timeout(timeout);
    } on TimeoutException {
      throw const OnlineScanException(OnlineFailure.timeout);
    } on IOException catch (error) {
      throw OnlineScanException(OnlineFailure.offline, '$error');
    }
    if (response.status == 429) {
      throw OnlineScanException(OnlineFailure.quota, _short(response.body));
    }
    if (response.status != 200) {
      throw OnlineScanException(
          OnlineFailure.failed, 'HTTP ${response.status}: ${_short(response.body)}');
    }
    try {
      return OnlineScan.fromResponse(response.body, spec);
    } catch (error) {
      throw OnlineScanException(OnlineFailure.failed, '$error');
    }
  }

  static String _short(String text) =>
      text.length <= 200 ? text : '${text.substring(0, 200)}…';
}
