import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

/// One food the plate detector found (docs/MODEL_CONTRACT.md §7).
class DetectedFood {
  const DetectedFood({
    required this.code,
    required this.score,
    required this.box,
    this.tentative = false,
    this.scores = const {},
  });

  /// A class of detector_classes.txt, e.g. 'com' or 'trung'.
  final String code;
  final double score;

  /// Where it is, as shares (0–1) of the upright photo's width and height.
  final Rect box;

  /// Below its class's threshold, kept only for the meat classifier to
  /// vouch for (contract §9.3); never shown as it is.
  final bool tentative;

  /// The box's score for each class asked for in [decodeDetections]
  /// (the meats), for the meat classifier's vote.
  final Map<String, double> scores;

  DetectedFood renamed(String to) =>
      DetectedFood(code: to, score: score, box: box, scores: scores);
}

/// Every food found on one photo, best first, and the photo's upright size.
class PlateDetection {
  const PlateDetection({
    this.foods = const [],
    this.width = 0,
    this.height = 0,
  });

  static const empty = PlateDetection();

  final List<DetectedFood> foods;
  final int width;
  final int height;

  /// The classes found, each once, best first.
  List<String> get codes => [
        for (final (i, food) in foods.indexed)
          if (foods.take(i).every((earlier) => earlier.code != food.code))
            food.code,
      ];

  int count(String code) => foods.where((food) => food.code == code).length;

  /// The best score of [code], or null when it was not found.
  double? score(String code) {
    for (final food in foods) {
      if (food.code == code) return food.score;
    }
    return null;
  }
}

/// What the app puts on the plate for each detector class (contract §7.1):
/// the component with the same code, or a stand-in.
const detectorFoods = <String, String>{
  'com': 'com',
  'bun': 'bun',
  'mi': 'mi',
  'banh_mi_o': 'banh_mi_o',
  'ga': 'ga',
  'thit_kho': 'thit_kho',
  'thit_nuong': 'thit_nuong',
  'heo': 'heo',
  'bo': 'bo',
  'ca': 'ca',
  'tom': 'tom',
  'muc': '_base_muc_chien',
  'trung': 'trung_kho',
  'dau_hu': 'dau_hu',
  'cha': 'cha_lua',
  'cha_gio': '_base_cha_gio',
  'rau': 'rau_nau',
  'dua_leo_ca_chua': 'dua_leo_ca_chua',
  'do_chua': 'do_chua',
  'khoai_tay_chien': '_base_khoai_tay_chien',
  'canh': '_base_canh_chua',
};

/// Classes whose boxes are counted, one unit each: an egg or a roll is
/// boxed on its own, a pile of shrimp or sliced sausage often in one box.
const countedDetectorClasses = {'trung', 'cha_gio', 'banh_mi_o'};

/// Classes with no component of their own, made from a variant instead
/// (group, "part|skin|style").
const detectorVariantFoods = <String, (String, String)>{
  'heo': ('heo', 'nac_mo||luoc'),
};

/// The detector's labels and thresholds, from detector_classes.txt and
/// DETECTOR_CARD.md.
class DetectorLabels {
  const DetectorLabels({
    required this.classes,
    this.thresholdBox = 0.35,
    this.thresholdIou = 0.5,
    this.classThresholds = const {},
  });

  /// Throws [FormatException] when a class is not one the app knows.
  factory DetectorLabels.parse({
    required String classesTxt,
    String card = '',
  }) {
    final classes = [
      for (final line in classesTxt.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    final unknown = classes.where((code) => !detectorFoods.containsKey(code));
    if (classes.isEmpty || unknown.isNotEmpty) {
      throw FormatException('Unknown detector classes: ${unknown.join(', ')}');
    }
    double? value(String key) {
      final match =
          RegExp('^$key:\\s*([0-9.]+)', multiLine: true).firstMatch(card);
      final number = match == null ? null : double.tryParse(match.group(1)!);
      return number != null && number > 0 && number < 1 ? number : null;
    }

    return DetectorLabels(
      classes: classes,
      thresholdBox: value('threshold_box') ?? 0.35,
      thresholdIou: value('threshold_iou') ?? 0.5,
      classThresholds: {
        for (final code in classes)
          if (value('threshold_box_$code') case final number?) code: number,
      },
    );
  }

  final List<String> classes;
  final double thresholdBox;
  final double thresholdIou;

  /// `threshold_box_<class>` lines of the card (contract 1.7), for classes
  /// whose own threshold differs from [thresholdBox].
  final Map<String, double> classThresholds;

  /// The lowest score a box of [code] needs to count.
  double thresholdFor(String code) => classThresholds[code] ?? thresholdBox;
}

/// How a photo was fitted into the model's square input: shrunk by [scale]
/// and centred, the rest grey (contract §7.2).
class Letterbox {
  Letterbox({required this.width, required this.height, required this.size})
      : scale = size / math.max(width, height) {
    fittedWidth = math.max(1, (width * scale).round());
    fittedHeight = math.max(1, (height * scale).round());
    left = (size - fittedWidth) ~/ 2;
    top = (size - fittedHeight) ~/ 2;
  }

  final int width;
  final int height;
  final int size;
  final double scale;
  late final int fittedWidth;
  late final int fittedHeight;
  late final int left;
  late final int top;

  /// A point of the input, as a share of its side, back on the photo.
  double photoX(double x) => ((x * size - left) / fittedWidth).clamp(0, 1);
  double photoY(double y) => ((y * size - top) / fittedHeight).clamp(0, 1);
}

/// The foods in one raw detector output of [shape] ([1, 4 + classes, A] or
/// [1, A, 4 + classes]): boxes above their class's threshold, then per class
/// only the best of boxes that overlap more than
/// [DetectorLabels.thresholdIou].
///
/// For the meat classifier (contract §9.3): boxes of a class in [floors]
/// are kept from that score up, marked [DetectedFood.tentative] below the
/// class's threshold, and boxes of a class in [scoresOf] carry their score
/// for each class of it.
List<DetectedFood> decodeDetections(
  Float32List output,
  List<int> shape,
  DetectorLabels labels,
  Letterbox letterbox, {
  Map<String, double> floors = const {},
  Set<String> scoresOf = const {},
}) {
  final channels = 4 + labels.classes.length;
  if (shape.length != 3 || shape[0] != 1 || !shape.contains(channels)) {
    throw FormatException('Detector output must be [1, $channels, A], '
        'got $shape');
  }
  final channelsFirst = shape[1] == channels;
  final anchors = channelsFirst ? shape[2] : shape[1];
  double at(int channel, int anchor) => channelsFirst
      ? output[channel * anchors + anchor]
      : output[anchor * channels + channel];

  // Boxes come as shares of the input; an export that keeps pixels has
  // values far above 1.
  var largest = 0.0;
  for (var a = 0; a < anchors; a++) {
    largest = math.max(largest, at(2, a));
  }
  final unit = largest > 2 ? letterbox.size.toDouble() : 1.0;

  final thresholds = [for (final code in labels.classes) labels.thresholdFor(code)];
  final lowest = [
    for (final (i, code) in labels.classes.indexed)
      math.min(thresholds[i], floors[code] ?? thresholds[i]),
  ];
  final scored = [
    for (final (i, code) in labels.classes.indexed)
      if (scoresOf.contains(code)) (i, code),
  ];
  final found = <DetectedFood>[];
  for (var a = 0; a < anchors; a++) {
    var best = 0;
    var score = at(4, a);
    for (var c = 1; c < labels.classes.length; c++) {
      final value = at(4 + c, a);
      if (value > score) {
        score = value;
        best = c;
      }
    }
    if (score < lowest[best]) continue;
    final cx = at(0, a) / unit, cy = at(1, a) / unit;
    final w = at(2, a) / unit, h = at(3, a) / unit;
    final box = Rect.fromLTRB(
      letterbox.photoX(cx - w / 2),
      letterbox.photoY(cy - h / 2),
      letterbox.photoX(cx + w / 2),
      letterbox.photoY(cy + h / 2),
    );
    if (box.width <= 0 || box.height <= 0) continue;
    final code = labels.classes[best];
    found.add(DetectedFood(
      code: code,
      score: score.toDouble(),
      box: box,
      tentative: score < thresholds[best],
      scores: scoresOf.contains(code)
          ? {for (final (i, other) in scored) other: at(4 + i, a).toDouble()}
          : const {},
    ));
  }
  return keepBestBoxes(found, labels.thresholdIou);
}

/// [foods] best first, and per class only the best of boxes that overlap
/// more than [iouLimit].
List<DetectedFood> keepBestBoxes(List<DetectedFood> foods, double iouLimit) {
  final sorted = [...foods]..sort((a, b) => b.score.compareTo(a.score));
  final kept = <DetectedFood>[];
  for (final food in sorted) {
    if (kept.every((other) =>
        other.code != food.code ||
        _overlap(other.box, food.box) <= iouLimit)) {
      kept.add(food);
    }
  }
  return kept;
}

/// Intersection over union of two boxes.
double _overlap(Rect a, Rect b) {
  final inter = a.intersect(b);
  if (inter.width <= 0 || inter.height <= 0) return 0;
  final shared = inter.width * inter.height;
  return shared / (a.width * a.height + b.width * b.height - shared);
}
