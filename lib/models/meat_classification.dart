import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'plate_detection.dart';

/// The classifier's class for food that is not one of the meats.
const notMeat = 'khac';

/// The meat classifier's classes and settings, from meat_classes.txt and
/// MEAT_CARD.md (docs/MODEL_CONTRACT.md §9).
class MeatLabels {
  const MeatLabels({
    required this.classes,
    this.cropPad = 0.1,
    this.votePower,
    this.renameFrom,
    this.boxFloor,
    this.rescueFrom,
    this.dropFrom,
  });

  /// Throws [FormatException] unless every class but `khac` is one of
  /// [detectorClasses] and `khac` is there.
  factory MeatLabels.parse({
    required String classesTxt,
    required List<String> detectorClasses,
    String card = '',
  }) {
    final classes = [
      for (final line in classesTxt.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    final unknown = classes
        .where((code) => code != notMeat && !detectorClasses.contains(code));
    if (!classes.contains(notMeat) || classes.length < 2 || unknown.isNotEmpty) {
      throw FormatException('Meat classes must be detector classes and khac, '
          'got ${classes.join(', ')}');
    }
    double? value(String key, {double above = 0, double upTo = 1}) {
      final match =
          RegExp('^$key:\\s*([0-9.]+)', multiLine: true).firstMatch(card);
      final number = match == null ? null : double.tryParse(match.group(1)!);
      return number != null && number > above && number <= upTo
          ? number
          : null;
    }

    final floor = value('box_floor');
    final rescue = value('threshold_rescue');
    return MeatLabels(
      classes: classes,
      cropPad: value('crop_pad', above: -1e-9, upTo: 0.5) ?? 0.1,
      votePower: value('vote_power', upTo: 10),
      renameFrom: value('threshold_rename'),
      // A floor needs its rescue threshold, and boxes under 0.10 were
      // never measured (§9.2).
      boxFloor: floor != null && floor >= 0.1 && rescue != null ? floor : null,
      rescueFrom: rescue,
      dropFrom: value('threshold_drop'),
    );
  }

  final List<String> classes;

  /// Share of the box's width and height added on each side before cutting.
  final double cropPad;

  /// `vote_power`: the box takes the meat with the best detector score ^
  /// this × classifier probability.
  final double? votePower;

  /// `threshold_rename`, used without [votePower].
  final double? renameFrom;

  /// `box_floor`: meat boxes from here up to their class threshold are
  /// classified too, and kept when the classifier is [rescueFrom] sure.
  final double? boxFloor;
  final double? rescueFrom;

  /// `threshold_drop`: a meat box the classifier calls khac this sure goes.
  final double? dropFrom;

  /// The meats, in output order.
  List<String> get meats => [
        for (final code in classes)
          if (code != notMeat) code,
      ];
}

/// Where the classifier cuts from: the detector's input, the photo fitted
/// into it as [letterbox] says, values 0–1, channels first or last.
typedef CropSource = ({
  Float32List input,
  Letterbox letterbox,
  bool channelsFirst,
});

/// The classifier's input for [box] (shares of the photo): the box grown by
/// [pad] of its size on each side, kept on the photo, sampled bilinearly
/// into [size]×[size] like `tf.image.crop_and_resize`, RGB 0–255 channels
/// last (contract §9.2).
Float32List cropForClassifier(CropSource source, Rect box,
    {required double pad, required int size}) {
  final letterbox = source.letterbox;
  final side = letterbox.size;
  final plane = side * side;
  final w = letterbox.fittedWidth, h = letterbox.fittedHeight;
  final x0 = math.max(0.0, box.left - pad * box.width);
  final x1 = math.min(1.0, box.right + pad * box.width);
  final y0 = math.max(0.0, box.top - pad * box.height);
  final y1 = math.min(1.0, box.bottom + pad * box.height);
  final input = source.input;
  double pixel(int x, int y, int channel) {
    final at = (y + letterbox.top) * side + x + letterbox.left;
    return source.channelsFirst
        ? input[channel * plane + at]
        : input[at * 3 + channel];
  }

  final out = Float32List(size * size * 3);
  final step = size > 1 ? 1 / (size - 1) : 0.0;
  for (var i = 0; i < size; i++) {
    final y = y0 * (h - 1) + i * (y1 - y0) * (h - 1) * step;
    final yLow = y.floor().clamp(0, h - 1);
    final yHigh = math.min(yLow + 1, h - 1);
    final fy = y - yLow;
    for (var j = 0; j < size; j++) {
      final x = x0 * (w - 1) + j * (x1 - x0) * (w - 1) * step;
      final xLow = x.floor().clamp(0, w - 1);
      final xHigh = math.min(xLow + 1, w - 1);
      final fx = x - xLow;
      for (var c = 0; c < 3; c++) {
        final top = pixel(xLow, yLow, c) * (1 - fx) + pixel(xHigh, yLow, c) * fx;
        final bottom =
            pixel(xLow, yHigh, c) * (1 - fx) + pixel(xHigh, yHigh, c) * fx;
        out[(i * size + j) * 3 + c] = (top * (1 - fy) + bottom * fy) * 255;
      }
    }
  }
  return out;
}

/// [foods] after the meat classifier's say (contract §9.3).
/// [probabilities] holds, for each food, the classifier's probability of
/// each of [MeatLabels.classes], or null when it did not look at it; a
/// tentative box it did not look at is dropped. Overlapping boxes of one
/// class are then thinned again, as renaming can make them.
List<DetectedFood> refineMeat(
  List<DetectedFood> foods,
  List<Map<String, double>?> probabilities,
  MeatLabels labels, {
  required double iouLimit,
}) {
  final meats = labels.meats;
  final kept = <DetectedFood>[];
  for (final (i, food) in foods.indexed) {
    final probs = i < probabilities.length ? probabilities[i] : null;
    if (probs == null) {
      if (!food.tentative) kept.add(food);
      continue;
    }
    var best = meats.first;
    for (final code in meats) {
      if ((probs[code] ?? 0) > (probs[best] ?? 0)) best = code;
    }
    final sure = probs[best] ?? 0;
    final other = probs[notMeat] ?? 0;
    final isMeat = sure > other;
    var vote = best;
    if (labels.votePower case final power?) {
      double weight(String code) =>
          math.pow(food.scores[code] ?? 0, power) * (probs[code] ?? 0);
      for (final code in meats) {
        if (weight(code) > weight(vote)) vote = code;
      }
    }
    if (food.tentative) {
      if (labels.boxFloor != null &&
          isMeat &&
          sure >= (labels.rescueFrom ?? 2) &&
          vote == best) {
        kept.add(food.renamed(best));
      }
      continue;
    }
    if (labels.dropFrom case final drop? when !isMeat && other >= drop) {
      continue;
    }
    if (labels.votePower != null) {
      kept.add(vote == food.code ? food : food.renamed(vote));
    } else if (labels.renameFrom case final from?
        when isMeat && best != food.code && sure >= from) {
      kept.add(food.renamed(best));
    } else {
      kept.add(food);
    }
  }
  return keepBestBoxes(kept, iouLimit);
}
