import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/models/meat_classification.dart';
import 'package:optifit/models/plate_detection.dart';

const _detectorClasses = [
  'com', 'bun', 'mi', 'banh_mi_o', 'ga', 'thit_kho', 'thit_nuong', 'heo',
  'bo', 'ca', 'tom', 'muc', 'trung', 'dau_hu', 'cha', 'cha_gio', 'rau',
  'dua_leo_ca_chua', 'do_chua', 'khoai_tay_chien', 'canh',
];
const _meatClasses = 'ga\nthit_kho\nthit_nuong\nheo\nbo\nca\ntom\nkhac\n';

MeatLabels _labels(String card) => MeatLabels.parse(
    classesTxt: _meatClasses, detectorClasses: _detectorClasses, card: card);

DetectedFood _food(String code, double score,
        {Rect box = const Rect.fromLTRB(0.1, 0.1, 0.4, 0.4),
        bool tentative = false,
        Map<String, double> scores = const {}}) =>
    DetectedFood(
        code: code,
        score: score,
        box: box,
        tentative: tentative,
        scores: scores);

/// Classifier probabilities: [sure] for [code], the rest spread evenly.
Map<String, double> _says(String code, double sure) {
  const all = ['ga', 'thit_kho', 'thit_nuong', 'heo', 'bo', 'ca', 'tom', 'khac'];
  return {
    for (final c in all) c: c == code ? sure : (1 - sure) / (all.length - 1),
  };
}

void main() {
  group('labels', () {
    test('settings come from the card; nonsense is ignored', () {
      final labels = _labels('contract_version: 1.8\ncrop_pad: 0.10\n'
          'vote_power: 0.5\nbox_floor: 0.20\nthreshold_rescue: 0.60\n'
          'threshold_drop: 0.80\nthreshold_rename: 4\n');
      expect(labels.meats,
          ['ga', 'thit_kho', 'thit_nuong', 'heo', 'bo', 'ca', 'tom']);
      expect(labels.cropPad, 0.1);
      expect(labels.votePower, 0.5);
      expect(labels.boxFloor, 0.2);
      expect(labels.rescueFrom, 0.6);
      expect(labels.dropFrom, 0.8);
      expect(labels.renameFrom, isNull);
    });

    test('a floor needs a rescue threshold and is at least 0.10', () {
      expect(_labels('box_floor: 0.2\n').boxFloor, isNull);
      expect(_labels('box_floor: 0.05\nthreshold_rescue: 0.6\n').boxFloor,
          isNull);
    });

    test('classes must be detector classes plus khac', () {
      expect(
          () => MeatLabels.parse(
              classesTxt: 'ga\npizza\nkhac',
              detectorClasses: _detectorClasses),
          throwsFormatException);
      expect(
          () => MeatLabels.parse(
              classesTxt: 'ga\nheo', detectorClasses: _detectorClasses),
          throwsFormatException);
    });

    test('the classifier in assets/models, if any, is one the app reads', () {
      final classes = File('assets/models/meat_classes.txt');
      if (!File('assets/models/meat_classifier.tflite').existsSync()) return;
      final card = File('assets/models/MEAT_CARD.md').readAsStringSync();
      final labels = MeatLabels.parse(
          classesTxt: classes.readAsStringSync(),
          detectorClasses: File('assets/models/detector_classes.txt')
              .readAsLinesSync()
              .where((line) => line.trim().isNotEmpty)
              .toList(),
          card: card);
      expect(labels.classes.last, notMeat);
      expect(card, contains('contract_version: 1.8'));
      expect(card, isNot(contains('QUICK TEST')));
      expect(RegExp('^crop_pad:', multiLine: true).hasMatch(card), isTrue);
    });
  });

  test('crops like tf.image.crop_and_resize, either channel order', () {
    // A 10×6 photo fitted into a 12 input: 12×7, two grey rows above.
    final letterbox = Letterbox(width: 10, height: 6, size: 12);
    expect((letterbox.fittedHeight, letterbox.top), (7, 2));
    double value(int x, int y, int c) => ((x * 7 + y * 13 + c * 29) % 50) / 50;
    final last = Float32List(12 * 12 * 3), first = Float32List(12 * 12 * 3);
    for (var y = 0; y < 12; y++) {
      for (var x = 0; x < 12; x++) {
        for (var c = 0; c < 3; c++) {
          last[(y * 12 + x) * 3 + c] = value(x, y, c);
          first[c * 144 + y * 12 + x] = value(x, y, c);
        }
      }
    }
    const box = Rect.fromLTRB(0.2, 0.1, 0.7, 0.9);
    // tf.image.crop_and_resize (TensorFlow 2.18) on the same values, the
    // sampling the notebook trains with.
    const expected = {
      (0, 0, 0): 179.571,
      (0, 4, 1): 72.981,
      (2, 2, 2): 39.015,
      (4, 0, 0): 82.059,
      (4, 4, 2): 92.769,
      (1, 3, 1): 109.548,
    };
    for (final channelsFirst in [false, true]) {
      final crop = cropForClassifier(
          (
            input: channelsFirst ? first : last,
            letterbox: letterbox,
            channelsFirst: channelsFirst,
          ),
          box,
          pad: 0.1,
          size: 5);
      for (final MapEntry(key: (i, j, c), :value) in expected.entries) {
        expect(crop[(i * 5 + j) * 3 + c], closeTo(value, 1e-2),
            reason: '($i, $j, $c), channels first: $channelsFirst');
      }
    }
  });

  group('refining', () {
    final voting = _labels('vote_power: 0.5\nbox_floor: 0.2\n'
        'threshold_rescue: 0.6\nthreshold_drop: 0.8\n');

    test('the vote renames a meat both models lean to', () {
      final heo = _food('heo', 0.6, scores: {'heo': 0.6, 'ga': 0.5});
      final refined =
          refineMeat([heo], [_says('ga', 0.9)], voting, iouLimit: 0.5);
      expect(refined.single.code, 'ga');
      expect(refined.single.score, 0.6);
    });

    test('a sure classifier alone does not outvote a sure detector', () {
      // 0.9^0.5 × 0.05 against 0.001^0.5 × 0.6: heo stays.
      final heo = _food('heo', 0.9, scores: {'heo': 0.9, 'ga': 0.001});
      final says = {..._says('ga', 0.6), 'heo': 0.05};
      expect(refineMeat([heo], [says], voting, iouLimit: 0.5).single.code,
          'heo');
    });

    test('a tentative box stays only when the classifier vouches for it', () {
      final low = _food('ga', 0.3, tentative: true, scores: {'ga': 0.3});
      expect(refineMeat([low], [_says('ga', 0.7)], voting, iouLimit: 0.5)
          .single
          .tentative, isFalse);
      expect(refineMeat([low], [_says('ga', 0.5)], voting, iouLimit: 0.5),
          isEmpty);
      expect(refineMeat([low], [null], voting, iouLimit: 0.5), isEmpty);
    });

    test('a box the classifier is sure is not meat goes', () {
      final bo = _food('bo', 0.7, scores: {'bo': 0.7});
      expect(refineMeat([bo], [_says('khac', 0.85)], voting, iouLimit: 0.5),
          isEmpty);
      expect(refineMeat([bo], [_says('khac', 0.7)], voting, iouLimit: 0.5),
          hasLength(1));
    });

    test('without a vote, renaming needs threshold_rename', () {
      final renaming = _labels('threshold_rename: 0.7\n');
      final ca = _food('ca', 0.6);
      expect(
          refineMeat([ca], [_says('ga', 0.8)], renaming, iouLimit: 0.5)
              .single
              .code,
          'ga');
      expect(
          refineMeat([ca], [_says('ga', 0.6)], renaming, iouLimit: 0.5)
              .single
              .code,
          'ca');
    });

    test('boxes renamed onto each other are thinned, others kept', () {
      final ga = _food('ga', 0.8, scores: {'ga': 0.8});
      final heo = _food('heo', 0.6,
          box: const Rect.fromLTRB(0.12, 0.1, 0.42, 0.4),
          scores: {'heo': 0.6, 'ga': 0.55});
      final com = _food('com', 0.9, box: const Rect.fromLTRB(0.5, 0.5, 1, 1));
      final refined = refineMeat(
          [com, ga, heo], [null, _says('ga', 0.9), _says('ga', 0.9)], voting,
          iouLimit: 0.5);
      expect(refined.map((f) => f.code), ['com', 'ga']);
    });
  });

  test('decoding keeps meat boxes from the floor, with their meat scores', () {
    const labels = DetectorLabels(classes: _detectorClasses);
    const anchors = 3;
    final channels = 4 + _detectorClasses.length;
    final out = Float32List(channels * anchors);
    void box(int a, String code, double score, double cx,
        {Map<String, double> also = const {}}) {
      out[0 * anchors + a] = cx;
      out[1 * anchors + a] = 0.5;
      out[2 * anchors + a] = 0.2;
      out[3 * anchors + a] = 0.2;
      out[(4 + _detectorClasses.indexOf(code)) * anchors + a] = score;
      for (final MapEntry(:key, :value) in also.entries) {
        out[(4 + _detectorClasses.indexOf(key)) * anchors + a] = value;
      }
    }

    box(0, 'heo', 0.6, 0.2, also: {'ga': 0.3});
    box(1, 'ga', 0.25, 0.5);
    box(2, 'com', 0.25, 0.8);
    final letterbox = Letterbox(width: 100, height: 100, size: 100);
    final plain =
        decodeDetections(out, [1, channels, anchors], labels, letterbox);
    expect(plain.map((f) => f.code), ['heo']);
    expect(plain.single.scores, isEmpty);
    final meats = {'ga', 'heo', 'bo'};
    final found = decodeDetections(
        out, [1, channels, anchors], labels, letterbox,
        floors: {for (final m in meats) m: 0.2}, scoresOf: meats);
    expect(found.map((f) => (f.code, f.tentative)),
        [('heo', false), ('ga', true)]);
    expect(found.first.scores['ga'], closeTo(0.3, 1e-6));
    expect(found.first.scores.keys.toSet(), meats);
  });
}
