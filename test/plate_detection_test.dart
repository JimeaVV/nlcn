import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:optifit/models/food_log_entry.dart';
import 'package:optifit/models/plate_detection.dart';
import 'package:optifit/models/scan_plate.dart';
import 'package:optifit/models/vn_food.dart';
import 'package:optifit/services/food_detector.dart';

const _classes = [
  'com', 'bun', 'mi', 'banh_mi_o', 'ga', 'thit_kho', 'thit_nuong', 'heo',
  'bo', 'ca', 'tom', 'muc', 'trung', 'dau_hu', 'cha', 'cha_gio', 'rau',
  'dua_leo_ca_chua', 'do_chua', 'khoai_tay_chien', 'canh',
];

const _labels = DetectorLabels(classes: _classes);

/// A raw output with [boxes] (class, score, cx, cy, w, h as shares of the
/// input) among [anchors] empty anchors, laid out as [shape] says.
(Float32List, List<int>) _output(
    List<(String, double, double, double, double, double)> boxes,
    {int anchors = 10,
    bool channelsFirst = true,
    double unit = 1}) {
  final channels = 4 + _classes.length;
  final out = Float32List(channels * anchors);
  void put(int channel, int anchor, double value) => out[channelsFirst
      ? channel * anchors + anchor
      : anchor * channels + channel] = value;
  for (final (a, (code, score, cx, cy, w, h)) in boxes.indexed) {
    put(0, a, cx * unit);
    put(1, a, cy * unit);
    put(2, a, w * unit);
    put(3, a, h * unit);
    put(4 + _classes.indexOf(code), a, score);
  }
  return (
    out,
    channelsFirst ? [1, channels, anchors] : [1, anchors, channels],
  );
}

VnFoodData _realData() {
  String read(String name) =>
      File('assets/data/vn_food/$name').readAsStringSync();
  return parseVnFoodData(
    componentsCsv: read('components.csv'),
    dishesCsv: read('dishes.csv'),
    dishNamesCsv: read('dish_names.csv'),
    variantsCsv: read('food_variants.csv'),
  );
}

void main() {
  group('labels', () {
    test('every contract class has an app food', () {
      final labels = DetectorLabels.parse(classesTxt: '${_classes.join('\n')}\n');
      expect(labels.classes, _classes);
      expect(labels.thresholdBox, 0.35);
      expect(labels.thresholdIou, 0.5);
    });

    test('thresholds come from the card; nonsense is ignored', () {
      final labels = DetectorLabels.parse(
          classesTxt: 'com\nga',
          card: '# Detector card\n\nthreshold_box: 0.28\nthreshold_iou: 7\n');
      expect(labels.thresholdBox, 0.28);
      expect(labels.thresholdIou, 0.5);
    });

    test('the detector in assets/models, if any, is one the app reads', () {
      final classes = File('assets/models/detector_classes.txt');
      final card = File('assets/models/DETECTOR_CARD.md');
      if (!classes.existsSync()) return;
      final labels = DetectorLabels.parse(
          classesTxt: classes.readAsStringSync(),
          card: card.readAsStringSync());
      expect(labels.classes, _classes);
      expect(card.readAsStringSync(), contains('contract_version: 1.6'));
      expect(card.readAsStringSync(), isNot(contains('not finished')));
      expect(RegExp('^threshold_box:', multiLine: true)
          .hasMatch(card.readAsStringSync()), isTrue);
    });

    test('an unknown class rejects the detector', () {
      expect(() => DetectorLabels.parse(classesTxt: 'com\npizza'),
          throwsFormatException);
    });

    test('each app food exists in the real data', () {
      final data = _realData();
      for (final code in _classes) {
        expect(detectedComponent(data, code)?.hasNutrition, isTrue,
            reason: code);
      }
    });
  });

  group('decoding', () {
    test('a wide photo: boxes map back past the grey bands', () {
      // 400×300 in 640: shrunk to 640×480, 80 px of grey above and below.
      final box = Letterbox(width: 400, height: 300, size: 640);
      expect(box.top, 80);
      expect(box.left, 0);
      final (out, shape) = _output([('com', 0.9, 0.5, 0.5, 0.5, 0.375)]);
      final found = decodeDetections(out, shape, _labels, box);
      expect(found, hasLength(1));
      expect(found.first.code, 'com');
      // 240 px tall in the input is half of the 480 px photo.
      expect(found.first.box.top, closeTo(0.25, 1e-6));
      expect(found.first.box.bottom, closeTo(0.75, 1e-6));
      expect(found.first.box.left, closeTo(0.25, 1e-6));
    });

    test('channels last and pixel boxes read the same', () {
      final box = Letterbox(width: 640, height: 640, size: 640);
      final (out, shape) = _output([('ga', 0.8, 0.3, 0.4, 0.2, 0.2)],
          channelsFirst: false, unit: 640);
      final found = decodeDetections(out, shape, _labels, box);
      expect(found.single.code, 'ga');
      expect(found.single.box.left, closeTo(0.2, 1e-6));
      expect(found.single.box.top, closeTo(0.3, 1e-6));
    });

    test('below the threshold is dropped; overlaps of one food merge', () {
      final box = Letterbox(width: 640, height: 640, size: 640);
      final (out, shape) = _output([
        ('trung', 0.9, 0.30, 0.5, 0.2, 0.2),
        ('trung', 0.7, 0.31, 0.5, 0.2, 0.2), // the same egg again
        ('trung', 0.8, 0.70, 0.5, 0.2, 0.2), // a second egg
        ('com', 0.6, 0.31, 0.5, 0.2, 0.2), // another food may overlap
        ('tom', 0.2, 0.5, 0.2, 0.1, 0.1), // too unsure
      ]);
      final found = decodeDetections(out, shape, _labels, box);
      expect([for (final f in found) f.code], ['trung', 'trung', 'com']);
      final plate = PlateDetection(foods: found, width: 640, height: 640);
      expect(plate.codes, ['trung', 'com']);
      expect(plate.count('trung'), 2);
      expect(plate.score('com'), closeTo(0.6, 1e-6));
    });

    test('an output of the wrong width is refused', () {
      expect(
          () => decodeDetections(Float32List(30), const [1, 3, 10], _labels,
              Letterbox(width: 1, height: 1, size: 640)),
          throwsFormatException);
    });

    test('the photo is letterboxed in grey, 0–1, in either layout', () {
      final photo = img.Image(width: 4, height: 2)
        ..clear(img.ColorRgb8(255, 0, 0));
      final png = Uint8List.fromList(img.encodePng(photo));
      final last = prepareDetectorInput(png, size: 8, channelsFirst: false);
      expect(last.letterbox.top, 2);
      // Row 0 is grey, row 2 is the red photo.
      expect(last.input[0], closeTo(114 / 255, 1e-6));
      expect(last.input[(2 * 8) * 3], 1);
      expect(last.input[(2 * 8) * 3 + 1], 0);
      final first = prepareDetectorInput(png, size: 8, channelsFirst: true);
      expect(first.input[2 * 8], 1, reason: 'red plane');
      expect(first.input[64 + 2 * 8], 0, reason: 'green plane');
    });
  });

  group('a plate from boxes', () {
    final data = _realData();
    PlateDetection plate(List<String> codes) => PlateDetection(foods: [
          for (final (i, code) in codes.indexed)
            DetectedFood(
                code: code,
                score: 0.9 - i * 0.1,
                box: Rect.fromLTWH(i * 0.2, 0.1, 0.2, 0.2)),
        ], width: 1000, height: 750);

    test('rice and chicken breast are two rows, logged by their own names',
        () {
      final scanned = ScanPlate.detected(data, plate(['com', 'ga']));
      expect(scanned.isDetected, isTrue);
      expect([for (final i in scanned.items) i.component.code], ['com', 'ga']);
      expect(scanned.dish.nameVi, 'Cơm + Thịt gà');
      expect(scanned.items.first.confidence, closeTo(0.9, 1e-9));
      final entries = scanned.toEntries(
          date: DateTime(2026, 10, 24), meal: MealSlot.lunch, languageCode: 'vi');
      expect([for (final e in entries) e.name], ['Cơm', 'Thịt gà']);
    });

    test('a pile of shrimp in one box keeps its usual portion', () {
      final scanned = ScanPlate.detected(data, plate(['com', 'tom']));
      final shrimp = scanned.items[1];
      expect(shrimp.inUnits, isTrue);
      expect(shrimp.amount, typicalPortion(data, shrimp.component).amount);
    });

    test('eggs are counted by their boxes; plain pork comes from a variant',
        () {
      final scanned =
          ScanPlate.detected(data, plate(['com', 'trung', 'trung', 'heo']));
      final egg = scanned.items[1];
      expect(egg.component.code, 'trung_kho');
      expect(egg.inUnits, isTrue);
      expect(egg.amount, 2);
      final pork = scanned.items[2];
      expect(pork.component.code, 'heo');
      expect(pork.component.nameVi, 'Heo nửa nạc nửa mỡ, luộc / hầm');
      expect(pork.component.kcalPer100g, 220);
    });

    test('a dish that holds every food found keeps its recipe', () {
      final comTam = data.dish('com_tam')!;
      expect(dishShowsAll(comTam, plate(['com', 'trung', 'thit_nuong'])),
          isTrue);
      expect(dishShowsAll(comTam, plate(['com', 'ga'])), isFalse);
    });
  });
}
