import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

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
  /// Side of the square photo the model takes, read from the model file.
  int get inputSize;

  Future<List<Float32List>> run(Float32List input);
}

/// Turns the photo at a path into the model input for a [size]×[size] model.
typedef PhotoPreparer = Future<Float32List> Function(
    String imagePath, int size);

/// Decodes and resizes off the UI isolate: a phone photo takes a second or
/// two in pure Dart.
Future<Float32List> preparePhotoInBackground(String imagePath, int size) =>
    Isolate.run(
        () => preprocessPhoto(File(imagePath).readAsBytesSync(), size: size));

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

  /// The previous photo's run. tflite_flutter's isolate interpreter returns
  /// at once with zeroed outputs while it is busy, so a photo taken before
  /// the last one finished would silently score 0 everywhere.
  Future<void> _previousRun = Future.value();

  @override
  bool get isAvailable => true;

  @override
  Future<FoodRecognition> recognize(String imagePath) async {
    final clock = Stopwatch()..start();
    // Opened first: the model says what size the photo must be.
    final ModelRunner runner;
    try {
      runner = await (_runner ??= _openRunner());
    } catch (_) {
      _runner = null; // Try again on the next photo.
      rethrow;
    }
    final opened = clock.elapsed;
    final input = await _prepare(imagePath, runner.inputSize);
    final prepared = clock.elapsed - opened;
    final outputs = _previousRun.then((_) => runner.run(input));
    _previousRun = outputs.then<void>((_) {}, onError: (_) {});
    final result = interpretOutputs(await outputs, labels);
    // The model time includes opening the interpreter on the first photo.
    final timing =
        RecognitionTiming(prepare: prepared, model: clock.elapsed - prepared);
    debugPrint('Scan timing: photo ${timing.prepare.inMilliseconds} ms, '
        'model ${timing.model.inMilliseconds} ms');
    return result.withTiming(timing);
  }
}

/// [ModelRunner] backed by tflite_flutter, invoking in a background isolate.
class TfliteModelRunner implements ModelRunner {
  TfliteModelRunner._(this._interpreter, this._isolate, this.inputSize);

  static Future<ModelRunner> open(AssetBundle bundle) async {
    final data = await bundle.load(modelAsset);
    // One thread by default; most phones have at least four cores.
    final options = InterpreterOptions()
      ..threads = math.min(4, Platform.numberOfProcessors);
    final interpreter = Interpreter.fromBuffer(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        options: options);
    try {
      interpreter.allocateTensors();
      final input = interpreter.getInputTensors();
      final shape = input.length == 1 ? input.first.shape : const <int>[];
      if (input.length != 1 ||
          input.first.type != TensorType.float32 ||
          shape.length != 4 ||
          shape[0] != 1 ||
          shape[1] != shape[2] ||
          shape[1] < 32 ||
          shape[3] != 3) {
        throw FormatException('Model input must be float32 [1, N, N, 3], got '
            '${input.map((t) => '${t.type} ${t.shape}').join(', ')}');
      }
      if (interpreter
          .getOutputTensors()
          .any((tensor) => tensor.type != TensorType.float32)) {
        throw const FormatException('Model outputs must be float32');
      }
      final isolate =
          await IsolateInterpreter.create(address: interpreter.address);
      return TfliteModelRunner._(interpreter, isolate, shape[1]);
    } catch (_) {
      interpreter.close();
      rethrow;
    }
  }

  final Interpreter _interpreter;
  final IsolateInterpreter _isolate;

  @override
  final int inputSize;

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
