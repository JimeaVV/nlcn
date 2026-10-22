import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:optifit/models/vn_food.dart';
import 'package:optifit/services/food_model.dart';
import 'package:optifit/services/food_recognizer.dart';
import 'package:optifit/services/tflite_food_recognizer.dart';

/// Serves an in-memory asset set, including the manifest Flutter generates.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec()
          .encodeMessage({for (final name in files.keys) name: <Object>[]})!;
    }
    final text = files[key];
    if (text == null) throw StateError('missing $key');
    return ByteData.sublistView(Uint8List.fromList(text.codeUnits));
  }
}

class _FakeRunner implements ModelRunner {
  _FakeRunner(this.outputs, {this.inputSize = modelInputSize});

  final List<Float32List> outputs;

  @override
  final int inputSize;
  Float32List? lastInput;

  @override
  Future<List<Float32List>> run(Float32List input) async {
    lastInput = input;
    return outputs;
  }
}

class _SlowRunner implements ModelRunner {
  _SlowRunner(this.body);

  final Future<List<Float32List>> Function() body;

  @override
  int get inputSize => modelInputSize;

  @override
  Future<List<Float32List>> run(Float32List input) => body();
}

void main() {
  const labels = ModelLabels(dishes: [
    'com_tam',
    'pho_bo'
  ], components: [
    'com',
    'suon_nuong',
    'trung_op_la',
  ]);

  group('ModelLabels.parse', () {
    test('reads codes in order and skips blank lines', () {
      final parsed = ModelLabels.parse(
        dishesTxt: 'com_tam\r\npho_bo\n\n',
        componentsTxt: 'com\nsuon_nuong\ntrung_op_la\n',
      );
      expect(parsed.dishes, ['com_tam', 'pho_bo']);
      expect(parsed.components, ['com', 'suon_nuong', 'trung_op_la']);
      expect(parsed.thresholds.checked, RecognitionThresholds.contract.checked);
    });

    test('takes tuned thresholds from the model card', () {
      final parsed = ModelLabels.parse(
        dishesTxt: 'a\nb',
        componentsTxt: 'c',
        modelCard: '## Ngưỡng\n- `threshold_checked`: 0.55\n'
            '- threshold_ask = .25\nthreshold_confident_dish: 0.4\n'
            'threshold_unknown: 0.9\n',
      );
      expect(parsed.thresholds.checked, 0.55);
      expect(parsed.thresholds.ask, 0.25);
      expect(parsed.thresholds.confidentDish, 0.4);
    });

    test('reads which dishes the components can be trusted for', () {
      ModelLabels parse(String card) => ModelLabels.parse(
          dishesTxt: 'com_tam\npho_bo', componentsTxt: 'c', modelCard: card);
      expect(
          parse('## Thành phần\r\ncomponent_dishes: com_tam, com_phan\r\n')
              .componentDishes,
          {'com_tam', 'com_phan'});
      expect(parse('- `component_dishes`: `com_tam`').componentDishes,
          {'com_tam'});
      expect(parse('component_dishes:\nthreshold_ask: 0.2').componentDishes,
          isEmpty);
      expect(parse('threshold_ask: 0.2').componentDishes, isEmpty,
          reason: 'an older card trusts no dish');
      final recognition = interpretOutputs([
        Float32List.fromList([0.9, 0.1]),
        Float32List.fromList([0.8]),
      ], parse('component_dishes: com_tam'));
      expect(recognition.knowsComponentsOf('com_tam'), isTrue);
      expect(recognition.knowsComponentsOf('pho_bo'), isFalse);
      expect(const FoodRecognition().knowsComponentsOf('pho_bo'), isTrue);
    });

    test('rejects files the app could not map', () {
      expect(() => ModelLabels.parse(dishesTxt: '', componentsTxt: 'c'),
          throwsFormatException);
      expect(() => ModelLabels.parse(dishesTxt: 'a\na', componentsTxt: 'c'),
          throwsFormatException);
      // Equal lengths would make the two outputs indistinguishable.
      expect(() => ModelLabels.parse(dishesTxt: 'a', componentsTxt: 'c'),
          throwsFormatException);
      expect(
          () => ModelLabels.parse(
              dishesTxt: 'a\nb',
              componentsTxt: 'c',
              modelCard: 'threshold_checked: 0.2\nthreshold_ask: 0.5'),
          throwsFormatException);
    });
  });

  group('preprocessPhoto', () {
    List<int> rgbAt(Float32List input, int x, int y) {
      final i = (y * modelInputSize + x) * 3;
      return [input[i].round(), input[i + 1].round(), input[i + 2].round()];
    }

    Matcher near(List<int> rgb) => predicate<List<int>>(
        (actual) => [0, 1, 2].every((i) => (actual[i] - rgb[i]).abs() <= 40),
        'within 40 of $rgb');

    test('crops the centre square and keeps raw 0-255 RGB', () {
      // 400×200: red on the left half, blue on the right half.
      final photo = img.Image(width: 400, height: 200);
      img.fillRect(photo,
          x1: 0, y1: 0, x2: 199, y2: 199, color: img.ColorRgb8(255, 0, 0));
      img.fillRect(photo,
          x1: 200, y1: 0, x2: 399, y2: 199, color: img.ColorRgb8(0, 0, 255));
      final input = preprocessPhoto(img.encodePng(photo));
      expect(input, hasLength(modelInputSize * modelInputSize * 3));
      // The centre square spans x 100–299, so red fills its left half.
      expect(rgbAt(input, 10, 112), near([255, 0, 0]));
      expect(rgbAt(input, 213, 112), near([0, 0, 255]));
    });

    test('turns the photo upright from its EXIF orientation', () {
      // Stored landscape with "rotate 90° clockwise": the left (red) edge
      // ends up on top once upright.
      final photo = img.Image(width: 300, height: 100);
      img.fillRect(photo,
          x1: 0, y1: 0, x2: 149, y2: 99, color: img.ColorRgb8(255, 0, 0));
      img.fillRect(photo,
          x1: 150, y1: 0, x2: 299, y2: 99, color: img.ColorRgb8(0, 0, 255));
      photo.exif.imageIfd.orientation = 6;
      final input = preprocessPhoto(img.encodeJpg(photo, quality: 95));
      expect(rgbAt(input, 112, 10), near([255, 0, 0]));
      expect(rgbAt(input, 112, 213), near([0, 0, 255]));
    });

    test('resizes to the size the model asks for', () {
      final photo = img.Image(width: 640, height: 480);
      expect(preprocessPhoto(img.encodePng(photo), size: 300),
          hasLength(300 * 300 * 3));
    });

    test('rejects bytes that are not an image', () {
      expect(() => preprocessPhoto(Uint8List.fromList([1, 2, 3])),
          throwsFormatException);
    });
  });

  group('the other-dish output', () {
    test('is never a guess and flags photos of unknown food', () {
      const unknown = FoodRecognition(
          dishes: {'com_tam': 0.2, otherDishCode: 0.7, 'pho_bo': 0.1});
      expect(unknown.topDishes().map((e) => e.key), ['com_tam', 'pho_bo']);
      expect(unknown.looksUnknown, isTrue);
      const known =
          FoodRecognition(dishes: {'com_tam': 0.8, otherDishCode: 0.2});
      expect(known.looksUnknown, isFalse);
      expect(known.topDishes(1).single.key, 'com_tam');
    });
  });

  group('interpretOutputs', () {
    test('matches outputs by length in either order', () {
      final result = interpretOutputs([
        Float32List.fromList([0.9, 0.2, double.nan]),
        Float32List.fromList([0.8, 0.2]),
      ], labels);
      expect(result.dishes,
          {'com_tam': closeTo(0.8, 1e-6), 'pho_bo': closeTo(0.2, 1e-6)});
      expect(result.components['com'], closeTo(0.9, 1e-6));
      expect(result.components['trung_op_la'], 0, reason: 'NaN counts as 0');
      expect(result.topDishes(1).single.key, 'com_tam');
    });

    test('names the expected sizes when the model does not fit', () {
      expect(
        () => interpretOutputs([Float32List(5), Float32List(2)], labels),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('3 components'))),
      );
    });
  });

  group('TfliteFoodRecognizer', () {
    test('prepares the photo, runs the model and keeps its thresholds',
        () async {
      // A 300x300 model, like EfficientNetB3: the photo is prepared to fit.
      final runner = _FakeRunner([
        Float32List.fromList([0.7, 0.3]),
        Float32List.fromList([0.95, 0.4, 0.1]),
      ], inputSize: 300);
      final input = Float32List(300 * 300 * 3);
      final recognizer = TfliteFoodRecognizer(
        labels: const ModelLabels(
          dishes: ['com_tam', 'pho_bo'],
          components: ['com', 'suon_nuong', 'trung_op_la'],
          thresholds: RecognitionThresholds(checked: 0.9),
        ),
        openRunner: () async => runner,
        prepare: (path, size) async {
          expect(path, 'plate.jpg');
          expect(size, 300);
          return input;
        },
      );
      expect(recognizer.isAvailable, isTrue);
      final result = await recognizer.recognize('plate.jpg');
      expect(identical(runner.lastInput, input), isTrue);
      expect(result.dishes['com_tam'], closeTo(0.7, 1e-6));
      expect(result.thresholds.checked, 0.9);
      expect(result.timing, isNotNull, reason: 'shown on the result screen');
      expect(
          result.timing!.total, result.timing!.prepare + result.timing!.model);
    });

    test('runs photos one after another, never overlapping', () async {
      var running = 0, peak = 0;
      final runner = _SlowRunner(() async {
        peak = math.max(peak, ++running);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        running--;
        return [
          Float32List.fromList([0.6, 0.4]),
          Float32List(3)
        ];
      });
      final recognizer = TfliteFoodRecognizer(
        labels: labels,
        openRunner: () async => runner,
        prepare: (_, __) async => Float32List(0),
      );
      final results = await Future.wait(
          [for (var i = 0; i < 3; i++) recognizer.recognize('$i.jpg')]);
      expect(peak, 1);
      expect(results.map((r) => r.dishes['com_tam']),
          everyElement(closeTo(0.6, 1e-6)));
    });

    test('retries opening the model after a failure', () async {
      var attempts = 0;
      final recognizer = TfliteFoodRecognizer(
        labels: labels,
        openRunner: () async {
          if (++attempts == 1) throw StateError('busy');
          return _FakeRunner([Float32List(2), Float32List(3)]);
        },
        prepare: (_, __) async => Float32List(0),
      );
      await expectLater(recognizer.recognize('a.jpg'), throwsStateError);
      await recognizer.recognize('a.jpg');
      expect(attempts, 2);
    });
  });

  group('loadFoodRecognizer', () {
    test('falls back to picking by hand without a bundled model', () async {
      final recognizer =
          await loadFoodRecognizer(bundle: _FakeBundle({'other.txt': ''}));
      expect(recognizer, isA<NoModelRecognizer>());
      expect(recognizer.isAvailable, isFalse);
    });

    test('loads labels and thresholds next to the model', () async {
      final recognizer = await loadFoodRecognizer(
        bundle: _FakeBundle({
          modelAsset: '',
          '$modelFolder/dishes.txt': 'com_tam\npho_bo\n',
          '$modelFolder/components.txt': 'com\nbo\nrau_song\n',
          '$modelFolder/MODEL_CARD.md': 'threshold_ask: 0.35\n',
        }),
      );
      expect(recognizer, isA<TfliteFoodRecognizer>());
      final labels = (recognizer as TfliteFoodRecognizer).labels;
      expect(labels.dishes, ['com_tam', 'pho_bo']);
      expect(labels.thresholds.ask, 0.35);
    });

    test('ignores a model whose label files are broken', () async {
      final recognizer = await loadFoodRecognizer(
        bundle: _FakeBundle({modelAsset: '', '$modelFolder/dishes.txt': 'a'}),
      );
      expect(recognizer, isA<NoModelRecognizer>());
    });
  });

  test('a bundled model only uses codes the nutrition tables know', () {
    final dishesFile = File('$modelFolder/dishes.txt');
    if (!File(modelAsset).existsSync() || !dishesFile.existsSync()) {
      markTestSkipped('No model bundled yet');
      return;
    }
    String read(String name) =>
        File('assets/data/vn_food/$name.csv').readAsStringSync();
    final data = parseVnFoodData(
      componentsCsv: read('components'),
      dishesCsv: read('dishes'),
      dishNamesCsv: read('dish_names'),
    );
    final labels = ModelLabels.parse(
      dishesTxt: dishesFile.readAsStringSync(),
      componentsTxt: File('$modelFolder/components.txt').readAsStringSync(),
    );
    expect(
        labels.dishes
            .where((code) => code != otherDishCode && data.dish(code) == null),
        isEmpty);
    final addable = {for (final c in data.addableComponents) c.code};
    expect(labels.components.where((code) => !addable.contains(code)), isEmpty);
  });
}
