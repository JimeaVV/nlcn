import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'food_model.dart';
import 'food_recognizer.dart';

/// Where the trained model ships (docs/MODEL_CONTRACT.md §6).
const modelFolder = 'assets/models';
const modelAsset = '$modelFolder/food_v1.tflite';

/// Runs the model on one prepared input; returns every output as float32.
abstract interface class ModelRunner {
  Future<List<Float32List>> run(Float32List input);
}

typedef PhotoPreparer = Future<Float32List> Function(String imagePath);

/// Decodes and resizes off the UI isolate: a phone photo takes a second or
/// two in pure Dart.
Future<Float32List> preparePhotoInBackground(String imagePath) =>
    Isolate.run(() => preprocessPhoto(File(imagePath).readAsBytesSync()));

/// Recognizes dishes with the bundled `.tflite` model. The interpreter opens
/// on the first photo, not at app start.
class TfliteFoodRecognizer implements FoodRecognizer {
  TfliteFoodRecognizer({
    required this.labels,
    required Future<ModelRunner> Function() openRunner,
    PhotoPreparer prepare = preparePhotoInBackground,
  })  : _openRunner = openRunner,
        _prepare = prepare;

  final ModelLabels labels;
  final Future<ModelRunner> Function() _openRunner;
  final PhotoPreparer _prepare;
  Future<ModelRunner>? _runner;

  @override
  bool get isAvailable => true;

  @override
  Future<FoodRecognition> recognize(String imagePath) async {
    final input = await _prepare(imagePath);
    final ModelRunner runner;
    try {
      runner = await (_runner ??= _openRunner());
    } catch (_) {
      _runner = null; // Try again on the next photo.
      rethrow;
    }
    return interpretOutputs(await runner.run(input), labels);
  }
}

/// [ModelRunner] backed by tflite_flutter, invoking in a background isolate.
class TfliteModelRunner implements ModelRunner {
  TfliteModelRunner._(this._interpreter, this._isolate);

  static Future<ModelRunner> open(AssetBundle bundle) async {
    final data = await bundle.load(modelAsset);
    final interpreter = Interpreter.fromBuffer(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    try {
      interpreter.allocateTensors();
      final input = interpreter.getInputTensors();
      const shape = [1, modelInputSize, modelInputSize, 3];
      if (input.length != 1 ||
          input.first.type != TensorType.float32 ||
          !listEquals(input.first.shape, shape)) {
        throw FormatException('Model input must be float32 $shape, got '
            '${input.map((t) => '${t.type} ${t.shape}').join(', ')}');
      }
      if (interpreter
          .getOutputTensors()
          .any((tensor) => tensor.type != TensorType.float32)) {
        throw const FormatException('Model outputs must be float32');
      }
      final isolate =
          await IsolateInterpreter.create(address: interpreter.address);
      return TfliteModelRunner._(interpreter, isolate);
    } catch (_) {
      interpreter.close();
      rethrow;
    }
  }

  final Interpreter _interpreter;
  final IsolateInterpreter _isolate;

  @override
  Future<List<Float32List>> run(Float32List input) async {
    final outputs = [
      for (final tensor in _interpreter.getOutputTensors())
        Float32List(tensor.numElements()),
    ];
    await _isolate.runForMultipleInputs(
      [input.buffer.asUint8List()],
      {for (var i = 0; i < outputs.length; i++) i: outputs[i].buffer},
    );
    return outputs;
  }
}

/// The model recognizer when `assets/models/` holds a model, otherwise
/// [NoModelRecognizer] so the scan screen falls back to picking by hand.
Future<FoodRecognizer> loadFoodRecognizer({AssetBundle? bundle}) async {
  final assets = bundle ?? rootBundle;
  try {
    final listed =
        (await AssetManifest.loadFromAssetBundle(assets)).listAssets().toSet();
    if (!listed.contains(modelAsset)) return const NoModelRecognizer();
    Future<String> read(String name) => assets.loadString('$modelFolder/$name');
    const card = '$modelFolder/MODEL_CARD.md';
    final labels = ModelLabels.parse(
      dishesTxt: await read('dishes.txt'),
      componentsTxt: await read('components.txt'),
      modelCard: listed.contains(card) ? await read('MODEL_CARD.md') : '',
    );
    return TfliteFoodRecognizer(
      labels: labels,
      openRunner: () => TfliteModelRunner.open(assets),
    );
  } catch (error) {
    // A broken model must not break scanning; logging by hand still works.
    debugPrint('Food model not loaded: $error');
    return const NoModelRecognizer();
  }
}
