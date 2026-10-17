import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/core/cyber_theme.dart';
import 'package:optifit/models/user_profile.dart';
import 'package:optifit/models/weight_entry.dart';
import 'package:optifit/screens/profile_screen.dart';
import 'package:optifit/services/database_service.dart';

import 'helpers/localized_app.dart';

class _Database extends Fake implements DatabaseService {
  _Database({UserProfile? profile, List<WeightEntry> weights = const []})
      : profile = profile?.toMap(),
        weights = List.of(weights);

  Map<String, dynamic>? profile;
  final List<WeightEntry> weights;
  final savedProfiles = <UserProfile>[];
  final savedWeights = <({double weight, DateTime date})>[];
  final deletedIds = <int>[];

  @override
  Future<Map<String, dynamic>?> getProfile() async => profile;

  @override
  Future<List<WeightEntry>> getWeightHistory({int limit = 90}) async =>
      (List<WeightEntry>.of(weights)
            ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt)))
          .take(limit)
          .toList();

  @override
  Future<void> saveUserProfile(UserProfile value,
      {DateTime? recordedAt}) async {
    savedProfiles.add(value);
    profile = value.toMap();
  }

  @override
  Future<void> saveWeight(
      {required double weight, DateTime? recordedAt}) async {
    final date = recordedAt!;
    savedWeights.add((weight: weight, date: date));
    final index = weights.indexWhere((entry) => entry.recordedAt == date);
    final entry = WeightEntry(
      id: index == -1 ? weights.length + 1 : weights[index].id,
      weight: weight,
      recordedAt: date,
    );
    if (index == -1) {
      weights.add(entry);
    } else {
      weights[index] = entry;
    }
    _syncCurrentWeight();
  }

  @override
  Future<void> deleteWeightEntry(int id) async {
    deletedIds.add(id);
    weights.removeWhere((entry) => entry.id == id);
    _syncCurrentWeight();
  }

  void _syncCurrentWeight() {
    if (profile == null || weights.isEmpty) return;
    final latest = (List<WeightEntry>.of(weights)
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt)))
        .first;
    profile!['weight'] = latest.weight;
  }
}

UserProfile _profile({double weight = 70, double? proteinOverride}) =>
    UserProfile(
      age: 21,
      gender: 'male',
      height: 175,
      weight: weight,
      activityLevel: 1.55,
      proteinOverride: proteinOverride,
    );

String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';

void main() {
  Future<void> open(
    WidgetTester tester,
    _Database database, {
    double width = 360,
    VoidCallback? onChanged,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(localizedApp(
      theme: AppTheme.build(AppStyle.minimalLight),
      home: Scaffold(
        body: ProfileScreen(database: database, onProfileChanged: onChanged),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String key, String value) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.enterText(finder, value);
    await tester.pump();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    FocusManager.instance.primaryFocus?.unfocus();
    // A confirmation snack bar may cover the lowest rows of the list.
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(finder, 400,
          scrollable: find.byType(Scrollable).first);
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> toggle(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await reveal(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> scrollToTop(WidgetTester tester) async {
    await tester.drag(find.byType(ListView), const Offset(0, 4000));
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<TextFormField>(find.byKey(ValueKey(key))).controller!.text;

  Future<void> saveProfile(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('save-profile'));
    await reveal(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('profile saves independently and manual targets reset separately',
      (tester) async {
    final database = _Database();
    var changed = 0;
    await open(tester, database, onChanged: () => changed++);

    await fill(tester, 'profile-age', '17');
    await saveProfile(tester);
    expect(find.text('Nhập tuổi từ 18 đến 100.'), findsOneWidget);
    expect(database.savedProfiles, isEmpty);

    await fill(tester, 'profile-age', '21');
    expect(find.byKey(const ValueKey('profile-calories')), findsNothing,
        reason: 'manual targets stay hidden until switched on');
    await toggle(tester, 'profile-custom-calories');
    expect(fieldText(tester, 'profile-calories'), '2625',
        reason: 'starts from the current estimate');
    await toggle(tester, 'profile-custom-protein');
    expect(fieldText(tester, 'profile-protein'), '126');
    await fill(tester, 'profile-calories', '1000');
    await fill(tester, 'profile-protein', '300');
    await saveProfile(tester);
    expect(find.textContaining('Năng lượng từ protein (4 kcal/g) không được'),
        findsOneWidget);
    expect(database.savedProfiles, isEmpty);

    await fill(tester, 'profile-calories', '2500');
    await fill(tester, 'profile-protein', '140');
    await saveProfile(tester);
    expect(database.savedProfiles.single.goal, NutritionGoal.maintain);
    expect(database.savedProfiles.single.calorieOverride, 2500);
    expect(database.savedProfiles.single.proteinOverride, 140);
    expect(changed, 1);
    await scrollToTop(tester);
    expect(find.text('tự đặt'), findsNWidgets(2));

    await toggle(tester, 'profile-custom-calories');
    expect(find.byKey(const ValueKey('profile-calories')), findsNothing);
    await saveProfile(tester);
    expect(database.savedProfiles.last.calorieOverride, isNull);
    expect(database.savedProfiles.last.proteinOverride, 140);
    await scrollToTop(tester);
    expect(find.text('ước tính'), findsOneWidget);
    expect(find.text('tự đặt'), findsOneWidget);
    expect(changed, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'backdated weight validates dates and supports edit and confirmed delete',
      (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    final database = _Database(profile: _profile(), weights: [
      WeightEntry(id: 1, weight: 70, recordedAt: today),
    ]);
    await open(tester, database, width: 320);
    await reveal(tester, find.byKey(const ValueKey('add-weight')));
    await tester.tap(find.byKey(const ValueKey('add-weight')));
    await tester.pumpAndSettle();

    await fill(tester, 'weight-log-value', '71.25');
    await fill(tester, 'weight-log-date', _date(tomorrow));
    await tester.tap(find.text('Lưu cân nặng'));
    await tester.pumpAndSettle();
    expect(find.text('Ngày cân không được sau hôm nay.'), findsOneWidget);
    expect(database.savedWeights, isEmpty);

    await fill(tester, 'weight-log-date', '31/02/2026');
    await tester.tap(find.text('Lưu cân nặng'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập ngày theo dạng ngày/tháng/năm.'), findsOneWidget);
    await fill(tester, 'weight-log-date', _date(yesterday));
    await tester.tap(find.text('Lưu cân nặng'));
    await tester.pumpAndSettle();
    expect(database.savedWeights.single.date, yesterday);
    expect(database.savedWeights.single.weight, 71.25);
    expect(find.textContaining('Gần nhất: 70 kg'), findsOneWidget);

    final edit = find.byKey(const ValueKey('edit-weight-2'));
    await reveal(tester, edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.descendant(
              of: find.byKey(const ValueKey('weight-log-date')),
              matching: find.byType(TextField),
            ))
            .readOnly,
        isTrue);
    expect(find.byTooltip('Chọn ngày cân'), findsNothing);
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(const ValueKey('weight-log-date')))
            .controller!
            .text,
        _date(yesterday));
    await fill(tester, 'weight-log-value', '72.5');
    await tester.tap(find.text('Lưu cân nặng'));
    await tester.pumpAndSettle();
    expect(database.savedWeights.last, (weight: 72.5, date: yesterday));
    expect(database.weights, hasLength(2));

    final delete = find.byKey(const ValueKey('delete-weight-2'));
    await reveal(tester, delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(database.deletedIds, isEmpty);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(database.deletedIds, isEmpty);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    expect(database.deletedIds, [2]);
    expect(database.weights, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('weight actions preserve unsaved profile fields and targets',
      (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final database = _Database(
      profile: _profile(),
      weights: [
        WeightEntry(id: 1, weight: 71, recordedAt: yesterday),
        WeightEntry(id: 2, weight: 70, recordedAt: today),
      ],
    );
    await open(tester, database);
    await fill(tester, 'profile-age', '25');
    await fill(tester, 'profile-height', '180');
    await reveal(tester, find.text('Nữ'));
    await tester.tap(find.text('Nữ'));
    await tester.pumpAndSettle();
    await reveal(tester, find.byType(DropdownButtonFormField<double>));
    await tester.tap(find.byType(DropdownButtonFormField<double>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhiều · ×1,725').last);
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Tăng cân'));
    await tester.tap(find.text('Tăng cân'));
    await tester.pumpAndSettle();
    await toggle(tester, 'profile-custom-calories');
    await toggle(tester, 'profile-custom-protein');
    await fill(tester, 'profile-calories', '2700');
    await fill(tester, 'profile-protein', '150');

    Future<void> expectDraft(String weight) async {
      await tester.drag(find.byType(ListView), const Offset(0, 2500));
      await tester.pumpAndSettle();
      String text(String key) => tester
          .widget<TextFormField>(find.byKey(ValueKey(key)))
          .controller!
          .text;
      expect(text('profile-age'), '25');
      expect(text('profile-height'), '180');
      expect(text('profile-weight'), weight);
      expect(text('profile-calories'), '2700');
      expect(text('profile-protein'), '150');
      expect(
          find.byKey(const ValueKey('profile-gender-female')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('profile-activity-1.725')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-goal-gain')), findsOneWidget);
      expect(database.savedProfiles, isEmpty);
    }

    await reveal(tester, find.byKey(const ValueKey('add-weight')));
    await tester.tap(find.byKey(const ValueKey('add-weight')));
    await tester.pumpAndSettle();
    await fill(tester, 'weight-log-value', '73.5');
    await tester.tap(find.text('Lưu cân nặng'));
    await tester.pumpAndSettle();
    await expectDraft('73.5');

    await reveal(tester, find.byKey(const ValueKey('edit-weight-1')));
    await tester.tap(find.byKey(const ValueKey('edit-weight-1')));
    await tester.pumpAndSettle();
    await fill(tester, 'weight-log-value', '69.5');
    await tester.tap(find.text('Lưu cân nặng'));
    await tester.pumpAndSettle();
    await expectDraft('73.5');

    await reveal(tester, find.byKey(const ValueKey('delete-weight-2')));
    await tester.tap(find.byKey(const ValueKey('delete-weight-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    await expectDraft('69.5');

    await saveProfile(tester);
    final saved = database.savedProfiles.single;
    expect(saved.age, 25);
    expect(saved.gender, 'female');
    expect(saved.height, 180);
    expect(saved.weight, 69.5);
    expect(saved.activityLevel, 1.725);
    expect(saved.goal, NutritionGoal.gain);
    expect(saved.calorieOverride, 2700);
    expect(saved.proteinOverride, 150);
    expect(tester.takeException(), isNull);
  });

  testWidgets('injected profiles remain isolated across screen instances',
      (tester) async {
    final first =
        _Database(profile: _profile(weight: 70, proteinOverride: 130));
    await open(tester, first);
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('profile-weight')))
            .controller!
            .text,
        '70');
    await tester.pumpWidget(const SizedBox.shrink());
    final second =
        _Database(profile: _profile(weight: 80, proteinOverride: 160));
    await open(tester, second);
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('profile-weight')))
            .controller!
            .text,
        '80');
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(const ValueKey('profile-protein')))
            .controller!
            .text,
        '160');
    expect(first.savedProfiles, isEmpty);
    expect(second.savedProfiles, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explanations live behind info buttons and old weigh-ins fold',
      (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final database = _Database(profile: _profile(), weights: [
      for (var day = 0; day < 7; day++)
        WeightEntry(
          id: day + 1,
          weight: 70 + day / 10,
          recordedAt: today.subtract(Duration(days: day)),
        ),
    ]);
    await open(tester, database);

    expect(find.textContaining('Mifflin'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('profile-how')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mifflin'), findsOneWidget);
    expect(find.textContaining('TDEE: 2.625 kcal'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('edit-weight-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-weight-6')), findsNothing);
    final showAll = find.byKey(const ValueKey('weights-show-all'));
    await reveal(tester, showAll);
    expect(find.text('Xem tất cả (7)'), findsOneWidget);
    await tester.tap(showAll);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('edit-weight-7')), findsOneWidget);
    expect(find.text('Thu gọn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
