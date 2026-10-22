import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/core/cyber_theme.dart';
import 'package:optifit/core/locale_controller.dart';
import 'package:optifit/models/food_log_entry.dart';
import 'package:optifit/models/history_models.dart';
import 'package:optifit/models/user_profile.dart';
import 'package:optifit/models/weight_entry.dart';
import 'package:optifit/screens/history_screen.dart';
import 'package:optifit/screens/scan_screen.dart';
import 'package:optifit/screens/settings_screen.dart';
import 'package:optifit/screens/today_screen.dart';
import 'package:optifit/services/database_service.dart';
import 'package:optifit/services/dataset_repository.dart';
import 'package:optifit/services/scan_camera.dart';
import 'package:optifit/widgets/optifit_bottom_bar.dart';
import 'package:optifit/widgets/section_tabs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/localized_app.dart';

class _Database extends Fake implements DatabaseService {
  Map<String, dynamic>? profile;
  List<FoodLogEntry> food = [];
  List<WeightEntry> weights = [];
  List<WorkoutLogEntry> logs = [];
  List<WorkoutHistoryEntry> workouts = [];
  List<MealHistoryEntry> meals = [];
  final added = <FoodLogEntry>[];
  var cleared = 0;
  final queried = <String>[];

  @override
  Future<Map<String, dynamic>?> getProfile() async => profile;

  @override
  Future<List<FoodLogEntry>> getFoodLog(DateTime day) async => food;

  @override
  Future<Map<DateTime, FoodLogTotals>> getDailyTotals(
      DateTime from, DateTime to) async {
    final days = <DateTime, List<FoodLogEntry>>{};
    for (final entry in food) {
      days
          .putIfAbsent(
              DateTime(entry.date.year, entry.date.month, entry.date.day),
              () => [])
          .add(entry);
    }
    return {
      for (final day in days.entries) day.key: FoodLogTotals.of(day.value)
    };
  }

  int water = 0;

  @override
  Future<int> getWater(DateTime day) async => water;

  @override
  Future<void> setWater(DateTime day, int ml) async => water = ml;

  @override
  Future<List<WeightEntry>> getWeightHistory({int limit = 90}) async => weights;

  @override
  Future<List<WorkoutLogEntry>> getWorkoutLogs() async {
    queried.add('logs');
    return logs;
  }

  @override
  Future<List<WorkoutHistoryEntry>> getWorkoutHistory() async {
    queried.add('workouts');
    return workouts;
  }

  @override
  Future<List<MealHistoryEntry>> getMealHistory() async {
    queried.add('meals');
    return meals;
  }

  @override
  Future<List<int>> addFoodLogEntries(List<FoodLogEntry> entries) async {
    added.addAll(entries);
    return [for (var i = 0; i < entries.length; i++) i + 1];
  }

  @override
  Future<void> clearAllHistory() async => cleared++;
}

class _Datasets extends DatasetRepository {
  @override
  Future<RecommendationData> load() async =>
      const RecommendationData(foods: [], exercises: []);
}

void _size(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

const _items = [
  BottomBarItem(icon: Icons.today, selectedIcon: Icons.today, label: 'Hôm nay'),
  BottomBarItem(
      icon: Icons.restaurant, selectedIcon: Icons.restaurant, label: 'Ăn uống'),
  BottomBarItem(
      icon: Icons.fitness_center,
      selectedIcon: Icons.fitness_center,
      label: 'Tập luyện'),
  BottomBarItem(icon: Icons.person, selectedIcon: Icons.person, label: 'Hồ sơ'),
];

void main() {
  testWidgets('scan sits in the middle and never becomes the selected tab',
      (tester) async {
    _size(tester, 320, 640);
    final selected = <int>[];
    var scans = 0;
    await tester.pumpWidget(localizedApp(
      home: Scaffold(
        bottomNavigationBar: MediaQuery(
          // Large system font: labels must shrink rather than wrap.
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: OptiFitBottomBar(
            items: _items,
            selectedIndex: 0,
            onSelected: selected.add,
            scanLabel: 'Quét',
            onScan: () => scans++,
          ),
        ),
      ),
    ));

    final centers = [
      for (final key in ['nav-0', 'nav-1', 'nav-scan', 'nav-2', 'nav-3'])
        tester.getCenter(find.byKey(ValueKey(key))).dx,
    ];
    expect(centers, orderedEquals([...centers]..sort()));
    expect(centers[2], closeTo(160, 1));

    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.tap(find.byKey(const ValueKey('nav-scan')));
    expect(selected, [2]);
    expect(scans, 1);

    final label = tester.widget<Text>(find.text('Tập luyện'));
    expect(label.maxLines, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('section tabs keep a page alive and report the shown tab',
      (tester) async {
    _size(tester, 400, 800);
    final shown = <int>[];
    final key = GlobalKey<SectionTabsState>();
    await tester.pumpWidget(localizedApp(
      theme: AppTheme.build(AppStyle.cyberpunk),
      home: Scaffold(
        body: SectionTabs(
          key: key,
          labels: const ['Một', 'Hai'],
          onChanged: shown.add,
          children: const [
            TextField(key: ValueKey('draft')),
            Text('Trang hai'),
          ],
        ),
      ),
    ));
    await tester.enterText(find.byKey(const ValueKey('draft')), 'chưa lưu');
    await tester.tap(find.text('Hai'));
    await tester.pumpAndSettle();
    expect(find.text('Trang hai'), findsOneWidget);
    key.currentState!.show(0);
    await tester.pumpAndSettle();
    expect(find.text('chưa lưu'), findsOneWidget);
    expect(shown, [1, 0]);
  });

  testWidgets('Today sums the diary, weight trend and training of the day',
      (tester) async {
    // Tall enough for every card, water and the week included.
    _size(tester, 400, 2600);
    final now = DateTime.now();
    final database = _Database()
      ..profile = const UserProfile(
        age: 25,
        gender: 'male',
        height: 175,
        weight: 70,
        activityLevel: 1.55,
        calorieOverride: 2000,
        proteinOverride: 120,
      ).toMap()
      ..food = [
        FoodLogEntry(
            date: now,
            meal: MealSlot.lunch,
            name: 'Cơm tấm',
            calories: 650,
            protein: 30),
        FoodLogEntry(
            date: now,
            meal: MealSlot.dinner,
            name: 'Phở bò',
            calories: 600,
            protein: 28),
      ]
      ..weights = [
        WeightEntry(id: 2, weight: 69.6, recordedAt: now),
        WeightEntry(
            id: 1,
            weight: 70,
            recordedAt: now.subtract(const Duration(days: 8))),
      ]
      ..logs = [
        WorkoutLogEntry.fromMap({
          'id': 1,
          'exercise_name': 'Bench Press',
          'weight_kg': 50,
          'set_1_reps': 12,
          'set_2_reps': 12,
          'set_3_reps': 12,
          'suggested_weight': 52.5,
          'suggested_reps': 8,
          'action': 'increase_weight',
          'suggestion_message': '',
          'performed_at': now.toIso8601String(),
        }),
      ];
    var diary = 0, scan = 0;
    await tester.pumpWidget(localizedApp(
      home: Scaffold(
        body: TodayScreen(
          database: database,
          onOpenDiary: () => diary++,
          onScan: () => scan++,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('1.250 / 2.000 kcal'), findsOneWidget);
    expect(find.text('Còn 750 kcal so với mục tiêu'), findsOneWidget);
    expect(find.text('Thay đổi 7 ngày: -0,4 kg'), findsOneWidget);
    expect(find.text('Đã ghi 1 bài tập hôm nay'), findsOneWidget);
    expect(find.text('1 ngày liên tục ghi ăn'), findsOneWidget);
    expect(find.text('Ghi ăn 1/7 ngày'), findsOneWidget);
    expect(find.text('Trung bình 1.250 kcal • 58,0 g protein mỗi ngày ghi'),
        findsOneWidget);
    expect(find.text('So với mục tiêu 2.000 kcal: -750 kcal/ngày'),
        findsOneWidget);
    expect(find.text('Tập 1 ngày'), findsOneWidget);

    expect(find.text('0 / 2.000 ml'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('water-add')));
    await tester.tap(find.byKey(const ValueKey('water-add')));
    await tester.pumpAndSettle();
    expect(find.text('500 / 2.000 ml'), findsOneWidget);
    expect(find.text('2 ly, mỗi ly 250 ml'), findsOneWidget);
    expect(database.water, 500);
    await tester.tap(find.byKey(const ValueKey('water-remove')));
    await tester.pumpAndSettle();
    expect(database.water, 250);

    await tester.tap(find.byKey(const ValueKey('today-open-diary')));
    await tester.tap(find.byKey(const ValueKey('today-scan')));
    expect([diary, scan], [1, 1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Scan logs a dish manually and reports it to the caller',
      (tester) async {
    _size(tester, 400, 1200);
    final database = _Database();
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
                    database: database,
                    camera: _NoCamera.new,
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
    expect(find.text('Quét món'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('scan-manual')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('diary-custom-name')), 'Bánh mì');
    await tester.enterText(
        find.byKey(const ValueKey('diary-custom-calories')), '350');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('diary-save')));
    await tester.pumpAndSettle();

    expect(database.added.single.name, 'Bánh mì');
    expect(result, isTrue);
  });

  testWidgets('each history section loads and shows only its own records',
      (tester) async {
    _size(tester, 400, 1200);
    final database = _Database();
    await tester.pumpWidget(localizedApp(
      home: Scaffold(
        body: HistoryScreen(section: HistorySection.meals, database: database),
      ),
    ));
    await tester.pumpAndSettle();
    expect(database.queried, ['meals']);
    expect(find.text('Chưa có thực đơn nào được lưu.'), findsOneWidget);
    expect(find.text('Chưa có buổi tập nào được lưu.'), findsNothing);

    database.queried.clear();
    await tester.pumpWidget(localizedApp(
      home: Scaffold(
        body:
            HistoryScreen(section: HistorySection.workouts, database: database),
      ),
    ));
    await tester.pumpAndSettle();
    expect(database.queried, ['workouts', 'logs']);
    expect(find.text('Chưa có buổi tập nào được lưu.'), findsOneWidget);
    expect(find.text('Chưa có nhật ký bài tập.'), findsOneWidget);
    expect(find.text('Chưa có thực đơn nào được lưu.'), findsNothing);
  });

  testWidgets('Settings clears saved history only after confirmation',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Tall enough for every Settings card down to the data card.
    _size(tester, 400, 3200);
    final database = _Database();
    var notified = 0;
    await tester.pumpWidget(localizedApp(
      home: Scaffold(
        body: SettingsScreen(
          themeController: ThemeController(),
          localeController: LocaleController(),
          database: database,
          onHistoryCleared: () => notified++,
        ),
      ),
    ));
    final clear = find.byKey(const ValueKey('clear-history'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(clear);
    await tester.pumpAndSettle();
    await tester.tap(clear);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(database.cleared, 0);

    await tester.tap(clear);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
    await tester.pumpAndSettle();
    expect(database.cleared, 1);
    expect(notified, 1);
    expect(find.text('Đã xóa lịch sử thực đơn và buổi tập.'), findsOneWidget);
  });
}

/// A phone without a usable camera: Scan shows its fallback actions.
class _NoCamera implements ScanCamera {
  @override
  Future<void> initialize() async =>
      throw const ScanCameraException(ScanCameraProblem.noCamera);

  @override
  Widget buildPreview() => const SizedBox();

  @override
  double get aspectRatio => 1;

  @override
  bool get hasFlash => false;

  @override
  Future<void> setTorch(bool on) async {}

  @override
  Future<void> focusAt(Offset point) async {}

  @override
  Future<String> takePicture() async => throw UnimplementedError();

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> dispose() async {}
}
