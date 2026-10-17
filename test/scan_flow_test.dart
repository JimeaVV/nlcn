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
    expect(find.text('Tổng: 620 kcal • 32,4 g protein'), findsOneWidget);

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
    expect(find.text('Tổng: 718 kcal • 39,2 g protein'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('scan-add-component')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-tom')));
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
  Future<String> takePicture() async => 'shot-${++shots}.jpg';

  @override
  Future<void> pause() async => paused = true;

  @override
  Future<void> resume() async => paused = false;

  @override
  Future<void> dispose() async => disposed = true;
}

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
