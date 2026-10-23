import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/models/food_log_entry.dart';
import 'package:optifit/screens/scan_result_screen.dart';
import 'package:optifit/screens/scan_screen.dart';
import 'package:optifit/services/database_service.dart';
import 'package:optifit/services/dataset_repository.dart';
import 'package:optifit/services/food_recognizer.dart';
import 'package:optifit/services/scan_camera.dart';
import 'package:optifit/services/vn_food_repository.dart';
import 'package:optifit/widgets/scan_button_face.dart';
import 'package:optifit/widgets/scan_sweep.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/localized_app.dart';
import 'helpers/vn_food_fixture.dart';

class _Database extends Fake implements DatabaseService {
  final added = <FoodLogEntry>[];

  @override
  Future<List<int>> addFoodLogEntries(List<FoodLogEntry> entries) async {
    for (final entry in entries) {
      entry.validate();
    }
    added.addAll(entries);
    return [for (var i = 0; i < entries.length; i++) i + 1];
  }
}

class _Recognizer implements FoodRecognizer {
  _Recognizer(this.result);

  final FoodRecognition result;
  final paths = <String>[];

  @override
  bool get isAvailable => true;

  @override
  Future<FoodRecognition> recognize(String imagePath) async {
    paths.add(imagePath);
    return result;
  }
}

class _Datasets extends DatasetRepository {
  @override
  Future<RecommendationData> load() async =>
      const RecommendationData(foods: [], exercises: []);
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<bool?> _openResult(
  WidgetTester tester, {
  required FoodRecognizer recognizer,
  required _Database database,
}) async {
  bool? result;
  await tester.pumpWidget(localizedApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: FilledButton(
          onPressed: () async {
            result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => ScanResultScreen(
                  imagePath: 'missing.jpg',
                  data: fixtureVnFood(),
                  recognizer: recognizer,
                  database: database,
                ),
              ),
            );
          },
          child: const Text('Mở'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Mở'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('a confident model opens the dish and asks about unsure parts',
      (tester) async {
    _tall(tester);
    final database = _Database();
    final recognizer = _Recognizer(const FoodRecognition(
      dishes: {'com_tam': 0.82, 'pho_bo': 0.18},
      components: {
        'com': 0.97,
        'suon_nuong': 0.91,
        'bi': 0.45,
        'trung_op_la': 0.8,
      },
    ));
    bool? popped;
    await tester.pumpWidget(localizedApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () async {
              popped = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => ScanResultScreen(
                    imagePath: 'plate.jpg',
                    data: fixtureVnFood(),
                    recognizer: recognizer,
                    database: database,
                  ),
                ),
              );
            },
            child: const Text('Mở'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();

    expect(recognizer.paths, ['plate.jpg']);
    expect(find.text('Cơm tấm · 82%'), findsOneWidget);
    expect(find.text('Có thể có'), findsOneWidget, reason: 'bì at 0.45');
    // Rice 260 + chop 250 + egg 98 + sauce 12.
    expect(find.text('Tổng: 620 kcal • 32,4 g protein'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('scan-save')));
    await tester.pumpAndSettle();
    expect(database.added.map((entry) => entry.name), [
      'Cơm (Cơm tấm)',
      'Sườn nướng (Cơm tấm)',
      'Trứng ốp la (Cơm tấm)',
      'Nước mắm chấm (Cơm tấm)',
    ]);
    expect(database.added.first.source, FoodLogSource.camera);
    expect(database.added.first.confidence, 0.97);
    expect(popped, isTrue);
  });

  testWidgets('a scanned part can be set to its cut and cooking',
      (tester) async {
    // The picker remembers the last choice per group.
    SharedPreferences.setMockInitialValues({});
    _tall(tester);
    final database = _Database();
    await tester.pumpWidget(localizedApp(
      home: ScanResultScreen(
        imagePath: 'plate.jpg',
        data: fixtureVnFood(
            variantsCsv: File('assets/data/vn_food/food_variants.csv')
                .readAsStringSync()),
        recognizer: _Recognizer(const FoodRecognition(
            dishes: {'com_tam': 0.95}, components: {'com': 0.97})),
        database: database,
      ),
    ));
    await tester.pumpAndSettle();
    // Rice, the egg and the chop have variants; the fixture's sauce has not.
    expect(find.byIcon(Icons.tune_rounded), findsNWidgets(3));

    await tester.tap(find.byKey(const ValueKey('refine-com')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('variant-part-com_lut')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('variant-choose')));
    await tester.pumpAndSettle();
    expect(find.text('Cơm gạo lứt'), findsOneWidget);
    // Opened again, the picker starts at that pick.
    await tester.tap(find.byKey(const ValueKey('refine-com')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(
                find.byKey(const ValueKey('variant-part-com_lut')))
            .selected,
        isTrue);
    await tester.tap(find.byKey(const ValueKey('variant-choose')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('scan-save')));
    await tester.pumpAndSettle();
    final rice = database.added.first;
    expect(rice.name, 'Cơm gạo lứt (Cơm tấm)');
    // 200 g at 123 kcal per 100 g.
    expect(rice.calories, closeTo(246, 1e-9));
  });

  testWidgets('the scan sweep plays a full pass even for an instant answer',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(localizedApp(
      home: ScanResultScreen(
        imagePath: 'plate.jpg',
        data: fixtureVnFood(),
        recognizer: _Recognizer(const FoodRecognition(
            dishes: {'com_tam': 0.9}, components: {'com': 0.9})),
        database: _Database(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Cơm tấm · 90%'), findsOneWidget, reason: 'not blocked');
    expect(find.byType(ScanSweep), findsOneWidget);
    await tester.pump(ScanSweep.onePass);
    await tester.pump();
    expect(find.byType(ScanSweep), findsNothing);
    expect(find.byKey(const ValueKey('scan-timing')), findsNothing,
        reason: 'no timing without a model run');
  });

  testWidgets('the result shows how long recognition took', (tester) async {
    _tall(tester);
    await _openResult(
      tester,
      recognizer: _Recognizer(const FoodRecognition(
              dishes: {'com_tam': 0.9}, components: {'com': 0.9})
          .withTiming(const RecognitionTiming(
              prepare: Duration(milliseconds: 640),
              model: Duration(milliseconds: 180)))),
      database: _Database(),
    );
    expect(find.text('Nhận diện trong 0,82 s (ảnh 0,64 s · model 0,18 s)'),
        findsOneWidget);
  });

  testWidgets('suggestions stay folded and the portion scales the dish',
      (tester) async {
    _tall(tester);
    await _openResult(
      tester,
      recognizer: _Recognizer(const FoodRecognition(
        dishes: {'com_tam': 0.9},
        components: {'com': 0.97, 'suon_nuong': 0.91, 'dua_leo_ca_chua': 0.9},
      )),
      database: _Database(),
    );
    // Rice 260 + chop 250 + sauce 12; bì and egg were not seen.
    expect(find.text('Tổng: 522 kcal • 25,6 g protein'), findsOneWidget);
    expect(find.text('Có thể có thêm (1)'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('component-dua_leo_ca_chua')), findsNothing,
        reason: 'outside the recipe: folded until asked for');

    await tester.tap(find.byKey(const ValueKey('portion-2.0')));
    await tester.pumpAndSettle();
    expect(find.text('Tổng: 1.044 kcal • 51,2 g protein'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('scan-suggestions')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('component-dua_leo_ca_chua')),
        matching: find.byType(Checkbox)));
    await tester.pumpAndSettle();
    expect(find.text('Có thể có thêm (1) · đã chọn 1'), findsOneWidget);
    // The salad doubled with the dish: 200 g, 32 kcal.
    expect(find.text('Tổng: 1.076 kcal • 52,6 g protein'), findsOneWidget);
  });

  testWidgets(
      'without a model the user picks the dish and missing data '
      'blocks logging until unticked', (tester) async {
    _tall(tester);
    final database = _Database();
    await _openResult(tester,
        recognizer: const NoModelRecognizer(), database: database);

    expect(
        find.text('Nhận diện tự động đang được huấn luyện. '
            'Tạm thời bạn chọn món sau khi chụp.'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('scan-save')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('scan-pick-dish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dish-com_tam')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Chưa có số liệu dinh dưỡng cho: Bì'),
        findsOneWidget);
    FilledButton save() =>
        tester.widget<FilledButton>(find.byKey(const ValueKey('scan-save')));
    expect(save().onPressed, isNull);

    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('component-bi')),
        matching: find.byType(Checkbox)));
    await tester.pumpAndSettle();
    expect(save().onPressed, isNotNull);

    // Two eggs instead of one: +98 kcal.
    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('component-trung_op_la')),
        matching: find.byIcon(Icons.add_circle_outline)));
    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('component-trung_op_la')),
        matching: find.byIcon(Icons.add_circle_outline)));
    await tester.pumpAndSettle();
    expect(find.text('Tổng: 718 kcal • 39,2 g protein'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('scan-add-component')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('single-tom')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('component-tom')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('scan-save')));
    await tester.tap(find.byKey(const ValueKey('scan-save')));
    await tester.pumpAndSettle();
    final egg = database.added
        .firstWhere((entry) => entry.name.startsWith('Trứng ốp la'));
    expect(egg.grams, 100);
    expect(egg.confidence, isNull);
    expect(database.added.any((entry) => entry.name.startsWith('Bì')), isFalse);
  });

  testWidgets('the picker searches without diacritics and logs one food alone',
      (tester) async {
    _tall(tester);
    final database = _Database();
    await _openResult(tester,
        recognizer: const NoModelRecognizer(), database: database);
    await tester.tap(find.byKey(const ValueKey('scan-pick-dish')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dish-com_tam')), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('food-picker-search')), 'pho');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dish-pho_bo')), findsOneWidget);
    expect(find.byKey(const ValueKey('dish-com_tam')), findsNothing);

    // No food is called "tôm luộc"; a word that starts a name still finds it.
    await tester.enterText(
        find.byKey(const ValueKey('food-picker-search')), 'tom luoc');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('single-tom')), findsOneWidget);
    expect(find.byKey(const ValueKey('single-com')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('single-tom')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('component-tom')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('scan-save')));
    await tester.tap(find.byKey(const ValueKey('scan-save')));
    await tester.pumpAndSettle();
    final shrimp = database.added.single;
    expect(shrimp.name, 'Tôm');
    expect(shrimp.calories, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the shutter takes a photo, reviews it and closes Scan',
      (tester) async {
    _tall(tester);
    final database = _Database();
    final camera = _FakeCamera();
    final result = await _openScan(
      tester,
      camera: camera,
      database: database,
      recognizer: _Recognizer(const FoodRecognition(
        dishes: {'pho_bo': 0.9},
        components: {'com': 0.9},
      )),
    );
    expect(find.byKey(const ValueKey('camera-preview')), findsOneWidget);
    expect(find.text('Đặt dĩa hoặc tô vào giữa khung'), findsOneWidget);
    expect(find.byType(ViewfinderFrame), findsOneWidget);
    // The frame sits on the photo's centre, which the model reads.
    final frame = tester.getCenter(find.byType(ViewfinderFrame));
    final preview =
        tester.getCenter(find.byKey(const ValueKey('camera-preview')));
    expect(frame.dx, closeTo(preview.dx, 1));
    expect(frame.dy, closeTo(preview.dy, 1));

    await tester.tap(find.byKey(const ValueKey('scan-shutter')));
    await tester.pumpAndSettle();
    expect(camera.shots, 1);
    expect(camera.paused, isTrue, reason: 'preview pauses during review');
    expect(find.text('Kết quả quét'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('scan-save')));
    await tester.pumpAndSettle();
    expect(database.added.single.name, 'Cơm (Phở bò)');
    expect(result(), isTrue, reason: 'Scan closes after logging');
    expect(camera.disposed, isTrue);
  });

  testWidgets('gallery and torch sit around the shutter; back resumes camera',
      (tester) async {
    _tall(tester);
    final camera = _FakeCamera();
    var picks = 0;
    await _openScan(
      tester,
      camera: camera,
      database: _Database(),
      recognizer: const NoModelRecognizer(),
      pickFromGallery: () async {
        picks++;
        return 'old.jpg';
      },
    );
    final gallery =
        tester.getCenter(find.byKey(const ValueKey('scan-gallery')));
    final shutter =
        tester.getCenter(find.byKey(const ValueKey('scan-shutter')));
    final manual = tester.getCenter(find.byKey(const ValueKey('scan-manual')));
    expect(gallery.dx, lessThan(shutter.dx));
    expect(manual.dx, greaterThan(shutter.dx));

    // Tapping the picture focuses there, mapped onto the uncropped preview.
    await tester.tapAt(preview(tester));
    await tester.pump();
    expect(camera.focused.single.dx, closeTo(0.5, 0.01));
    expect(camera.focused.single.dy, closeTo(0.5, 0.01));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('scan-torch')));
    await tester.pumpAndSettle();
    expect(camera.torch, isTrue);
    expect(find.byIcon(Icons.flash_on_rounded), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('scan-gallery')));
    await tester.pumpAndSettle();
    expect(picks, 1);
    expect(find.text('Kết quả quét'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(camera.paused, isFalse, reason: 'camera resumes after review');
    expect(find.byKey(const ValueKey('camera-preview')), findsOneWidget);
  });

  testWidgets('a cancelled gallery pick and the close button behave',
      (tester) async {
    _tall(tester);
    final camera = _FakeCamera();
    final result = await _openScan(
      tester,
      camera: camera,
      database: _Database(),
      recognizer: const NoModelRecognizer(),
      pickFromGallery: () async => null,
    );
    await tester.tap(find.byKey(const ValueKey('scan-gallery')));
    await tester.pumpAndSettle();
    expect(find.text('Kết quả quét'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('scan-close')));
    await tester.pumpAndSettle();
    expect(result(), isNull);
    expect(camera.disposed, isTrue);
  });

  testWidgets('a denied camera falls back to gallery and manual logging',
      (tester) async {
    _tall(tester);
    final camera = _FakeCamera(
        failure: const ScanCameraException(ScanCameraProblem.permissionDenied));
    await _openScan(
      tester,
      camera: camera,
      database: _Database(),
      recognizer: const NoModelRecognizer(),
    );
    expect(find.textContaining('chưa được phép dùng camera'), findsOneWidget);
    expect(find.byKey(const ValueKey('scan-gallery')), findsOneWidget);
    expect(find.byKey(const ValueKey('scan-manual')), findsOneWidget);
    expect(find.byKey(const ValueKey('scan-shutter')), findsNothing);
    expect(camera.disposed, isTrue);
  });
}

class _FakeCamera implements ScanCamera {
  _FakeCamera({this.failure});

  final ScanCameraException? failure;
  var shots = 0;
  var torch = false;
  var paused = false;
  var disposed = false;
  final focused = <Offset>[];

  @override
  Future<void> initialize() async {
    if (failure != null) throw failure!;
  }

  @override
  Widget buildPreview() => const ColoredBox(
      key: ValueKey('camera-preview'), color: Color(0xFF335544));

  @override
  double get aspectRatio => 3 / 4;

  @override
  bool get hasFlash => true;

  @override
  Future<void> setTorch(bool on) async => torch = on;

  @override
  Future<void> focusAt(Offset point) async => focused.add(point);

  @override
  Future<String> takePicture() async => 'shot-${++shots}.jpg';

  @override
  Future<void> pause() async => paused = true;

  @override
  Future<void> resume() async => paused = false;

  @override
  Future<void> dispose() async => disposed = true;
}

Offset preview(WidgetTester tester) =>
    tester.getCenter(find.byKey(const ValueKey('camera-preview')));

/// Pushes Scan over a home page; returns a getter for the popped value.
Future<bool? Function()> _openScan(
  WidgetTester tester, {
  required _FakeCamera camera,
  required _Database database,
  required FoodRecognizer recognizer,
  GalleryPicker? pickFromGallery,
}) async {
  bool? result;
  await tester.pumpWidget(localizedApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: FilledButton(
          onPressed: () async {
            result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => ScanScreen(
                  datasets: _Datasets(),
                  vnFood: VnFoodRepository(bundle: FixtureVnFoodBundle()),
                  recognizer: recognizer,
                  camera: () => camera,
                  pickFromGallery: pickFromGallery ?? () async => null,
                  database: database,
                ),
              ),
            );
          },
          child: const Text('Mở'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Mở'));
  await tester.pumpAndSettle();
  return () => result;
}
