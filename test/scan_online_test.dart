import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/models/food_log_entry.dart';
import 'package:optifit/models/plate_detection.dart';
import 'package:optifit/screens/scan_result_screen.dart';
import 'package:optifit/services/database_service.dart';
import 'package:optifit/services/food_detector.dart';
import 'package:optifit/services/food_recognizer.dart';
import 'package:optifit/services/online_recognizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/localized_app.dart';
import 'helpers/vn_food_fixture.dart';

class _Database extends Fake implements DatabaseService {
  final added = <FoodLogEntry>[];

  @override
  Future<List<int>> addFoodLogEntries(List<FoodLogEntry> entries) async {
    added.addAll(entries);
    return [for (var i = 0; i < entries.length; i++) i + 1];
  }
}

class _Recognizer implements FoodRecognizer {
  @override
  bool get isAvailable => true;

  @override
  Future<FoodRecognition> recognize(String imagePath) async =>
      const FoodRecognition(dishes: {'pho_bo': 0.4, 'com_tam': 0.1});
}

class _Detector implements FoodDetector {
  _Detector(List<String> codes)
      : result = PlateDetection(foods: [
          for (final (i, code) in codes.indexed)
            DetectedFood(
                code: code,
                score: 0.9 - i * 0.1,
                box: Rect.fromLTWH(0.1 + i * 0.3, 0.2, 0.25, 0.4)),
        ], width: 1200, height: 900);

  final PlateDetection result;

  @override
  bool get isAvailable => true;

  @override
  Future<PlateDetection> detect(String imagePath) async => result;
}

String _answer(List<Map<String, Object>> foods) => jsonEncode({
      'steps': [
        {
          'type': 'model_output',
          'content': [
            {'type': 'text', 'text': jsonEncode({'foods': foods})},
          ],
        },
      ],
    });

/// Online recognition that answers [reply] (or never), counting requests.
class _Online {
  _Online(this.reply);

  final Future<({int status, String body})> Function() reply;
  var requests = 0;

  late final recognizer = OnlineRecognizer(
    apiKey: 'test-key',
    spec: OnlineSpec.parse(
        File('assets/models/online_classes.json').readAsStringSync(), [
      for (final line
          in File('assets/models/detector_classes.txt').readAsLinesSync())
        if (line.trim().isNotEmpty) line.trim(),
    ]),
    readPhoto: (_) async => Uint8List(4),
    post: (_, __, ___) {
      requests++;
      return reply();
    },
  );
}

Future<void> _open(WidgetTester tester, _Online online, _Database database,
    {bool agreed = true}) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  await online.recognizer.setEnabled(true, consent: agreed);
  await tester.pumpWidget(localizedApp(
    home: ScanResultScreen(
      imagePath: 'plate.jpg',
      data: fixtureVnFood(
          variantsCsv: File('assets/data/vn_food/food_variants.csv')
              .readAsStringSync()),
      recognizer: _Recognizer(),
      detector: _Detector(['com', 'tom']),
      database: database,
      online: online.recognizer,
    ),
  ));
}

void main() {
  testWidgets('the plate follows what Gemini named, nutrition from the data',
      (tester) async {
    final database = _Database();
    final online = _Online(() async => (
          status: 200,
          body: _answer([
            {'class': 'com', 'name': 'rice', 'grams': 300},
            {'class': 'dua_leo_ca_chua', 'name': 'cucumber', 'grams': 40},
            {'class': 'other', 'name': 'mashed potatoes', 'grams': 80},
          ]),
        ));
    await _open(tester, online, database);
    await tester.pumpAndSettle();

    expect(online.requests, 1);
    expect(find.text('Gemini thấy 2 món'), findsOneWidget);
    expect(find.byKey(const ValueKey('scan-online-others')), findsOneWidget);
    expect(find.textContaining('mashed potatoes'), findsOneWidget);
    // Only the detector's rice box is drawn: Gemini saw no shrimp.
    expect(
        find.bySemanticsLabel(RegExp('khung quanh các món tìm thấy: Cơm\$')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('scan-save')));
    await tester.pumpAndSettle();
    expect([for (final entry in database.added) entry.name],
        ['Cơm', 'Dưa leo / cà chua']);
    // The usual portion, not Gemini's 300 g, at the fixture's 130 kcal.
    expect(database.added.first.grams, 150);
    expect(database.added.first.calories, closeTo(195, 1e-9));
  });

  testWidgets('with no answer the detector plate is used and the user is told',
      (tester) async {
    final online = _Online(() async => (
          status: 429,
          body: '{"error":{"message":"limit: 500 requests per day"}}',
        ));
    await _open(tester, online, _Database());
    await tester.pumpAndSettle();

    expect(find.text('Đĩa có 2 món'), findsOneWidget);
    expect(find.textContaining('Hết lượt Gemini hôm nay'), findsOneWidget);
  });

  testWidgets('the user can stop waiting for Gemini', (tester) async {
    final never = Completer<({int status, String body})>();
    final online = _Online(() => never.future);
    await _open(tester, online, _Database());
    await tester.pump();
    await tester.pump();

    expect(find.text('Đang hỏi Gemini (dev test)…'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('scan-use-offline')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Đĩa có 2 món'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    // Let the request's own timeout run out.
    await tester.pump(onlineTimeout);
  });

  testWidgets('without the user agreeing no photo is sent', (tester) async {
    final online = _Online(() async => (status: 200, body: _answer(const [])));
    await _open(tester, online, _Database(), agreed: false);
    await tester.pumpAndSettle();

    expect(online.requests, 0);
    expect(find.text('Đĩa có 2 món'), findsOneWidget);
  });
}
