import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'food_recognizer.dart';

/// Side of the square image most models take. Each model sets its own
/// (EfficientNetB3 reads 300); the app reads it from the .tflite file
/// (docs/MODEL_CONTRACT.md §6).
const modelInputSize = 224;

/// The label files that ship next to the model, parsed.
class ModelLabels {
  const ModelLabels({
    required this.dishes,
    required this.components,
    this.thresholds = RecognitionThresholds.contract,
    this.componentDishes,
  });

  /// `dishes.txt` and `components.txt` hold one code per line in output
  /// order; `MODEL_CARD.md` may override the thresholds with lines such as
  /// `threshold_checked: 0.55`, and lists the dishes whose components the
  /// model learned in `component_dishes: com_tam, com_phan`. A card without
  /// that line trusts the components of no dish.
  factory ModelLabels.parse({
    required String dishesTxt,
    required String componentsTxt,
    String modelCard = '',
  }) {
    final dishes = _codes(dishesTxt, 'dishes.txt');
    final components = _codes(componentsTxt, 'components.txt');
    if (dishes.length == components.length) {
      // Outputs are told apart by their length.
      throw const FormatException(
          'dishes.txt and components.txt must have different lengths');
    }
    return ModelLabels(
      dishes: dishes,
      components: components,
      thresholds: _thresholds(modelCard),
      componentDishes: _componentDishes(modelCard),
    );
  }

  final List<String> dishes;
  final List<String> components;
  final RecognitionThresholds thresholds;

  /// See [FoodRecognition.componentDishes].
  final Set<String>? componentDishes;

  static Set<String> _componentDishes(String modelCard) {
    final match = RegExp(r'^\s*(?:[-*]\s*)?`?component_dishes`?\s*:(.*)$',
            multiLine: true)
        .firstMatch(modelCard);
    if (match == null) return const {};
    return {
      for (final code in match.group(1)!.split(RegExp(r'[,\s`]+')))
        if (code.isNotEmpty) code,
    };
  }

  static List<String> _codes(String text, String file) {
    final codes = [
      for (final line in text.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    if (codes.isEmpty) throw FormatException('$file is empty');
    if (codes.toSet().length != codes.length) {
      throw FormatException('$file repeats a code');
    }
    return codes;
  }

  static RecognitionThresholds _thresholds(String modelCard) {
    final values = <String, double>{};
    final pattern =
        RegExp(r'(threshold_[a-z_]+)`?\s*[:=]\s*`?([0-9]*\.?[0-9]+)');
    for (final match in pattern.allMatches(modelCard)) {
      final value = double.parse(match.group(2)!);
      if (value >= 0 && value <= 1) values[match.group(1)!] = value;
    }
    const fallback = RecognitionThresholds.contract;
    final thresholds = RecognitionThresholds(
      checked: values['threshold_checked'] ?? fallback.checked,
      ask: values['threshold_ask'] ?? fallback.ask,
      confidentDish:
          values['threshold_confident_dish'] ?? fallback.confidentDish,
    );
    if (thresholds.ask > thresholds.checked) {
      throw const FormatException(
          'threshold_ask must not exceed threshold_checked');
    }
    return thresholds;
  }
}

/// Decodes a photo and turns it into the model input: upright, the centre
/// square, resized to the model's N×N with bilinear sampling, RGB values
/// 0–255 as float32 in row-major HWC order. Normalisation happens inside the
/// model.
///
/// Pure Dart so it can run in a background isolate.
Float32List preprocessPhoto(Uint8List encoded, {int size = modelInputSize}) {
  final decoded = img.decodeImage(encoded);
  if (decoded == null) throw const FormatException('Not a readable image');
  // Phone cameras store rotation in EXIF instead of turning the pixels.
  final upright = img.bakeOrientation(decoded);
  final side = math.min(upright.width, upright.height);
  final square = img.copyCrop(
    upright,
    x: (upright.width - side) ~/ 2,
    y: (upright.height - side) ~/ 2,
    width: side,
    height: side,
  );
  final resized = img.copyResize(
    square,
    width: size,
    height: size,
    interpolation: img.Interpolation.linear,
  );
  final input = Float32List(size * size * 3);
  var i = 0;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final pixel = resized.getPixel(x, y);
      input[i++] = pixel.r.toDouble();
      input[i++] = pixel.g.toDouble();
      input[i++] = pixel.b.toDouble();
    }
  }
  return input;
}

/// Maps raw model outputs to codes. The two outputs are matched to
/// `dishes.txt` and `components.txt` by length, so their order in the
/// `.tflite` file does not matter.
FoodRecognition interpretOutputs(
    List<Float32List> outputs, ModelLabels labels) {
  Float32List? dishOut, componentOut;
  for (final output in outputs) {
    if (output.length == labels.dishes.length) dishOut = output;
    if (output.length == labels.components.length) componentOut = output;
  }
  if (dishOut == null || componentOut == null) {
    throw FormatException('Model outputs have lengths '
        '${outputs.map((o) => o.length).join(', ')}, expected '
        '${labels.dishes.length} dishes and '
        '${labels.components.length} components');
  }
  double probability(double value) =>
      value.isFinite ? value.clamp(0.0, 1.0).toDouble() : 0.0;
  return FoodRecognition(
    dishes: {
      for (var i = 0; i < labels.dishes.length; i++)
        labels.dishes[i]: probability(dishOut[i]),
    },
    components: {
      for (var i = 0; i < labels.components.length; i++)
        labels.components[i]: probability(componentOut[i]),
    },
    thresholds: labels.thresholds,
    componentDishes: labels.componentDishes,
  );
}
