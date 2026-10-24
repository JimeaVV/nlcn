import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/plate_detection.dart';
import 'tflite_food_recognizer.dart' show modelFolder;

/// Where the optional plate detector ships (docs/MODEL_CONTRACT.md §7).
const detectorAsset = '$modelFolder/detector.tflite';

/// Finds each food on a photo of a plate.
abstract interface class FoodDetector {
  /// False when no detector is bundled; scanning then uses the dish model
  /// alone.
  bool get isAvailable;

  Future<PlateDetection> detect(String imagePath);
}

class NoFoodDetector implements FoodDetector {
  const NoFoodDetector();

  @override
  bool get isAvailable => false;

  @override
  Future<PlateDetection> detect(String imagePath) async =>
      PlateDetection.empty;
}

/// The photo fitted into the detector's input, and how it was fitted.
typedef DetectorInput = ({Float32List input, Letterbox letterbox});

/// Letterboxes [encoded] into a [size]×[size] input, values 0–1, grey
/// (114) around it; channels last, or first when [channelsFirst].
DetectorInput prepareDetectorInput(Uint8List encoded,
    {required int size, required bool channelsFirst}) {
  final decoded = img.decodeImage(encoded);
  if (decoded == null) throw const FormatException('Not a readable image');
  final upright = img.bakeOrientation(decoded);
  final box =
      Letterbox(width: upright.width, height: upright.height, size: size);
  final fitted = img.copyResize(upright,
      width: box.fittedWidth,
      height: box.fittedHeight,
      interpolation: img.Interpolation.linear);
  const grey = 114 / 255;
  final input = Float32List(size * size * 3)..fillRange(0, size * size * 3, grey);
  final plane = size * size;
  for (var y = 0; y < fitted.height; y++) {
    for (var x = 0; x < fitted.width; x++) {
      final pixel = fitted.getPixel(x, y);
      final at = (y + box.top) * size + x + box.left;
      if (channelsFirst) {
        input[at] = pixel.r / 255;
        input[plane + at] = pixel.g / 255;
        input[2 * plane + at] = pixel.b / 255;
      } else {
        input[at * 3] = pixel.r / 255;
        input[at * 3 + 1] = pixel.g / 255;
        input[at * 3 + 2] = pixel.b / 255;
      }
    }
  }
  return (input: input, letterbox: box);
}

/// Runs the bundled detector; the interpreter opens on the first photo.
class TfliteFoodDetector implements FoodDetector {
  TfliteFoodDetector({required this.labels, required AssetBundle bundle})
      : _bundle = bundle;

  final DetectorLabels labels;
  final AssetBundle _bundle;
  Future<_DetectorRunner>? _runner;
  Future<void> _previousRun = Future.value();

  @override
  bool get isAvailable => true;

  @override
  Future<PlateDetection> detect(String imagePath) async {
    final _DetectorRunner runner;
    try {
      runner = await (_runner ??= _DetectorRunner.open(_bundle, labels));
    } catch (_) {
      _runner = null;
      rethrow;
    }
    final clock = Stopwatch()..start();
    final size = runner.inputSize;
    final channelsFirst = runner.channelsFirst;
    // Decoding a phone photo takes a second or two in pure Dart.
    final prepared = await Isolate.run(() => prepareDetectorInput(
        File(imagePath).readAsBytesSync(),
        size: size,
        channelsFirst: channelsFirst));
    final photo = clock.elapsed;
    // One run at a time: a busy isolate interpreter returns zeros.
    final output = _previousRun.then((_) => runner.run(prepared.input));
    _previousRun = output.then<void>((_) {}, onError: (_) {});
    final foods = decodeDetections(
        await output, runner.outputShape, labels, prepared.letterbox);
    debugPrint('Detector timing: photo ${photo.inMilliseconds} ms, model '
        '${(clock.elapsed - photo).inMilliseconds} ms, ${foods.length} foods');
    return PlateDetection(
      foods: foods,
      width: prepared.letterbox.width,
      height: prepared.letterbox.height,
    );
  }
}

class _DetectorRunner {
  _DetectorRunner._(this._interpreter, this._isolate, this.inputSize,
      this.channelsFirst, this.outputShape);

  static Future<_DetectorRunner> open(
      AssetBundle bundle, DetectorLabels labels) async {
    final data = await bundle.load(detectorAsset);
    final options = InterpreterOptions()
      ..threads = math.min(4, Platform.numberOfProcessors);
    final interpreter = Interpreter.fromBuffer(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        options: options);
    try {
      interpreter.allocateTensors();
      final inputs = interpreter.getInputTensors();
      final outputs = interpreter.getOutputTensors();
      final shape = inputs.length == 1 ? inputs.first.shape : const <int>[];
      // [1, 3, S, S] (LiteRT export) or [1, S, S, 3] (onnx2tf).
      final channelsFirst = shape.length == 4 && shape[1] == 3;
      final size = shape.length != 4 ? 0 : shape[channelsFirst ? 2 : 1];
      final square = shape.length == 4 &&
          shape[0] == 1 &&
          (channelsFirst
              ? shape[2] == shape[3]
              : shape[1] == shape[2] && shape[3] == 3);
      if (inputs.length != 1 ||
          inputs.first.type != TensorType.float32 ||
          !square ||
          size < 32) {
        throw FormatException('Detector input must be float32 [1, 3, S, S] '
            'or [1, S, S, 3], got ${inputs.map((t) => t.shape).join(', ')}');
      }
      final channels = 4 + labels.classes.length;
      if (outputs.length != 1 ||
          outputs.first.type != TensorType.float32 ||
          !outputs.first.shape.contains(channels)) {
        throw FormatException('Detector output must be float32 with $channels '
            'channels, got ${outputs.map((t) => t.shape).join(', ')}');
      }
      final isolate =
          await IsolateInterpreter.create(address: interpreter.address);
      return _DetectorRunner._(interpreter, isolate, size, channelsFirst,
          outputs.first.shape);
    } catch (_) {
      interpreter.close();
      rethrow;
    }
  }

  final Interpreter _interpreter;
  final IsolateInterpreter _isolate;
  final int inputSize;
  final bool channelsFirst;
  final List<int> outputShape;

  Future<Float32List> run(Float32List input) async {
    final output =
        Float32List(_interpreter.getOutputTensors().first.numElements());
    await _isolate.runForMultipleInputs(
        [input.buffer.asUint8List()], {0: output.buffer});
    return output;
  }
}

/// The detector when `assets/models/` holds one, otherwise [NoFoodDetector].
/// A broken detector never breaks scanning.
Future<FoodDetector> loadFoodDetector({AssetBundle? bundle}) async {
  final assets = bundle ?? rootBundle;
  try {
    final listed =
        (await AssetManifest.loadFromAssetBundle(assets)).listAssets().toSet();
    if (!listed.contains(detectorAsset)) return const NoFoodDetector();
    const card = '$modelFolder/DETECTOR_CARD.md';
    final labels = DetectorLabels.parse(
      classesTxt: await assets.loadString('$modelFolder/detector_classes.txt'),
      card: listed.contains(card) ? await assets.loadString(card) : '',
    );
    return TfliteFoodDetector(labels: labels, bundle: assets);
  } catch (error) {
    debugPrint('Plate detector not loaded: $error');
    return const NoFoodDetector();
  }
}
