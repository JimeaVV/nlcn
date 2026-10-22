import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/core/cyber_theme.dart';
import 'package:optifit/core/locale_controller.dart';
import 'package:optifit/models/food_log_entry.dart';
import 'package:optifit/screens/settings_screen.dart';
import 'package:optifit/services/backup_service.dart';
import 'package:optifit/services/database_service.dart';
import 'package:optifit/services/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/localized_app.dart';

class _Scheduler implements ReminderScheduler {
  bool allow = true;
  List<MealReminder>? scheduled;
  var cancelled = 0;

  @override
  Future<bool> requestPermission() async => allow;

  @override
  Future<void> schedule(List<MealReminder> reminders,
          {required String channelName}) async =>
      scheduled = reminders;

  @override
  Future<void> cancelAll() async {
    cancelled++;
    scheduled = null;
  }
}

class _Database extends Fake implements DatabaseService {
  Map<String, dynamic>? restored;

  @override
  Future<void> restoreBackup(Map<String, dynamic> backup) async {
    if (backup['app'] != 'optifit') throw const FormatException('no');
    restored = backup;
  }
}

class _Backup extends BackupService {
  _Backup(this.file);

  final Map<String, dynamic>? file;

  @override
  Future<Map<String, dynamic>?> pick() async => file;
}

Future<void> _mount(WidgetTester tester,
    {ReminderController? reminders,
    DatabaseService? database,
    BackupService backup = const BackupService(),
    VoidCallback? onRestored}) async {
  tester.view.physicalSize = const Size(400, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(localizedApp(
    home: Scaffold(
      body: SettingsScreen(
        themeController: ThemeController(),
        localeController: LocaleController(),
        reminders: reminders,
        database: database,
        backup: backup,
        onDataRestored: onRestored,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('reminders are scheduled for three meals and can be turned off',
      (tester) async {
    final scheduler = _Scheduler();
    final reminders = ReminderController(scheduler: scheduler);
    await reminders.load();
    await _mount(tester, reminders: reminders);
    expect(find.text('Nhắc ghi bữa'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reminders-switch')));
    await tester.pumpAndSettle();
    expect(reminders.enabled, isTrue);
    final scheduled = scheduler.scheduled!;
    expect([for (final r in scheduled) r.meal],
        [MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner]);
    expect(scheduled[1].time, const TimeOfDay(hour: 12, minute: 30));
    expect(scheduled[1].title, 'Bữa trưa: bạn đã ghi chưa?');

    // The choice survives a restart.
    final again = ReminderController(scheduler: _Scheduler());
    await again.load();
    expect(again.enabled, isTrue);

    await tester.tap(find.byKey(const ValueKey('reminders-switch')));
    await tester.pumpAndSettle();
    expect(reminders.enabled, isFalse);
    expect(scheduler.cancelled, 1);
  });

  testWidgets('a refused permission leaves reminders off and says why',
      (tester) async {
    final scheduler = _Scheduler()..allow = false;
    final reminders = ReminderController(scheduler: scheduler);
    await _mount(tester, reminders: reminders);
    await tester.tap(find.byKey(const ValueKey('reminders-switch')));
    await tester.pumpAndSettle();
    expect(reminders.enabled, isFalse);
    expect(scheduler.scheduled, isNull);
    expect(
        find.textContaining('Chưa được cấp quyền thông báo'), findsOneWidget);
  });

  testWidgets('a changed reminder time is rescheduled', (tester) async {
    final scheduler = _Scheduler();
    final reminders = ReminderController(scheduler: scheduler);
    await reminders.setEnabled(true,
        texts: (meal) => (title: '$meal', body: ''), channelName: 'test');
    await reminders.setTime(
        MealSlot.dinner, const TimeOfDay(hour: 20, minute: 15),
        texts: (meal) => (title: '$meal', body: ''), channelName: 'test');
    expect(
        scheduler.scheduled!.singleWhere((r) => r.meal == MealSlot.dinner).time,
        const TimeOfDay(hour: 20, minute: 15));
  });

  testWidgets('restoring asks first, then replaces the data', (tester) async {
    final database = _Database();
    var restored = 0;
    await _mount(tester,
        database: database,
        backup: _Backup({'app': 'optifit', 'schema': 6, 'tables': {}}),
        onRestored: () => restored++);

    await tester.tap(find.byKey(const ValueKey('backup-import')));
    await tester.pumpAndSettle();
    expect(find.text('Khôi phục dữ liệu?'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(database.restored, isNull);

    await tester.tap(find.byKey(const ValueKey('backup-import')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khôi phục'));
    await tester.pumpAndSettle();
    expect(database.restored, isNotNull);
    expect(restored, 1);
    expect(find.text('Đã khôi phục dữ liệu.'), findsOneWidget);
  });

  testWidgets('an invalid backup file is reported, nothing restored',
      (tester) async {
    final database = _Database();
    await _mount(tester,
        database: database, backup: _Backup({'app': 'something else'}));
    await tester.tap(find.byKey(const ValueKey('backup-import')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khôi phục'));
    await tester.pumpAndSettle();
    expect(database.restored, isNull);
    expect(find.text('File này không phải bản sao lưu MacroRunner hợp lệ.'),
        findsOneWidget);
  });
}
