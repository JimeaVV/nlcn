import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/meat_classification.dart';
import 'tflite_food_recognizer.dart' show modelFolder;

/// Where the optional meat classifier ships (docs/MODEL_CONTRACT.md §9).
const meatClassifierAsset = '$modelFolder/meat_classifier.tflite';

/// Looks again at the meat boxes the plate detector found.
abstract interface class MeatClassifier {
  MeatLabels get labels;

  /// For each of [boxes] (shares of the photo), the probability of each of
  /// [MeatLabels.classes], cut from [source].
  Future<List<Map<String, double>>> classify(
      CropSource source, List<Rect> boxes);
}

/// Runs the bundled classifier; the interpreter opens on the first box.
class TfliteMeatClassifier implements MeatClassifier {
  TfliteMeatClassifier({required this.labels, required AssetBundle bundle})
      : _bundle = bundle;

  @override
  final MeatLabels labels;
  final AssetBundle _bundle;
  Future<_MeatRunner>? _runner;
  Future<void> _previousRun = Future.value();

  @override
  Future<List<Map<String, double>>> classify(
      CropSource source, List<Rect> boxes) async {
    final _MeatRunner runner;
    try {
      runner = await (_runner ??= _MeatRunner.open(_bundle, labels));
    } catch (_) {
      _runner = null;
      rethrow;
    }
    // One run at a time: a busy isolate interpreter returns zeros.
    final done = _previousRun.then((_) async => [
          for (final box in boxes)
            await runner.run(cropForClassifier(source, box,
                pad: labels.cropPad, size: runner.inputSize)),
        ]);
    _previousRun = done.then<void>((_) {}, onError: (_) {});
    return done;
  }
}

class _MeatRunner {
  _MeatRunner._(this._interpreter, this._isolate, this.inputSize, this._labels);

  static Future<_MeatRunner> open(AssetBundle bundle, MeatLabels labels) async {
    final data = await bundle.load(meatClassifierAsset);
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
      if (inputs.length != 1 ||
          inputs.first.type != TensorType.float32 ||
          shape.length != 4 ||
          shape[0] != 1 ||
          shape[1] != shape[2] ||
          shape[3] != 3 ||
          shape[1] < 32) {
        throw FormatException('Meat classifier input must be float32 '
            '[1, N, N, 3], got ${inputs.map((t) => t.shape).join(', ')}');
      }
      if (outputs.length != 1 ||
          outputs.first.type != TensorType.float32 ||
          outputs.first.numElements() != labels.classes.length) {
        throw FormatException('Meat classifier output must be float32 with '
            '${labels.classes.length} values, got '
            '${outputs.map((t) => t.shape).join(', ')}');
      }
      final isolate =
          await IsolateInterpreter.create(address: interpreter.address);
      return _MeatRunner._(interpreter, isolate, shape[1], labels);
    } catch (_) {
      interpreter.close();
      rethrow;
    }
  }

  final Interpreter _interpreter;
  final IsolateInterpreter _isolate;
  final int inputSize;
  final MeatLabels _labels;

  Future<Map<String, double>> run(Float32List input) async {
    final output =
        Float32List(_interpreter.getOutputTensors().first.numElements());
    await _isolate
        .runForMultipleInputs([input.buffer.asUint8List()], {0: output.buffer});
    return {
      for (final (i, code) in _labels.classes.indexed) code: output[i],
    };
  }
}

/// The classifier when `assets/models/` holds one, otherwise null. A broken
/// classifier never breaks scanning.
Future<MeatClassifier?> loadMeatClassifier(
    {required AssetBundle bundle,
    required List<String> detectorClasses,
    Set<String>? listed}) async {
  try {
    final assets = listed ??
        (await AssetManifest.loadFromAssetBundle(bundle)).listAssets().toSet();
    if (!assets.contains(meatClassifierAsset)) return null;
    const card = '$modelFolder/MEAT_CARD.md';
    return TfliteMeatClassifier(
      labels: MeatLabels.parse(
        classesTxt: await bundle.loadString('$modelFolder/meat_classes.txt'),
        detectorClasses: detectorClasses,
        card: assets.contains(card) ? await bundle.loadString(card) : '',
      ),
      bundle: bundle,
    );
  } catch (error) {
    debugPrint('Meat classifier not loaded: $error');
    return null;
  }
}
