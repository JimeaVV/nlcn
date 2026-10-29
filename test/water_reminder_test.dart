import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/core/cyber_theme.dart';
import 'package:optifit/core/locale_controller.dart';
import 'package:optifit/l10n/app_localizations_vi.dart';
import 'package:optifit/screens/settings_screen.dart';
import 'package:optifit/services/database_service.dart';
import 'package:optifit/services/reminder_service.dart';
import 'package:optifit/services/water_reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/localized_app.dart';

class _Scheduler implements WaterReminderScheduler {
  bool allow = true;
  List<WaterReminder>? scheduled;
  var cancelled = 0;

  @override
  Future<bool> requestPermission() async => allow;

  @override
  Future<void> schedule(List<WaterReminder> reminders,
          {required String channelName}) async =>
      scheduled = reminders;

  @override
  Future<void> cancelAll() async {
    cancelled++;
    scheduled = null;
  }
}

class _MealScheduler implements ReminderScheduler {
  var cancelled = 0;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> schedule(List<MealReminder> reminders,
      {required String channelName}) async {}

  @override
  Future<void> cancelAll() async => cancelled++;
}

class _Database extends Fake implements DatabaseService {
  _Database(this.water);

  final int water;

  @override
  Future<int> getWater(DateTime day) async => water;
}

final _texts = WaterReminderTexts.of(AppLocalizationsVi());
final _now = DateTime(2026, 10, 22, 9, 30);
const _eight = TimeOfDay(hour: 8, minute: 0);
const _ten = TimeOfDay(hour: 22, minute: 0);

String _hm(DateTime t) =>
    '${t.day} ${t.hour}:${t.minute.toString().padLeft(2, '0')}';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('plan', () {
    test('every 2 hours from 8:00 to 22:00, only after now', () {
      final plan = planWaterReminders(
          now: _now,
          everyHours: 2,
          from: _eight,
          to: _ten,
          goalReachedToday: false,
          texts: _texts,
          random: Random(1),
          days: 2);
      expect([
        for (final r in plan) _hm(r.when)
      ], [
        '22 10:00', '22 12:00', '22 14:00', '22 16:00', '22 18:00', //
        '22 20:00', '22 22:00',
        '23 8:00', '23 10:00', '23 12:00', '23 14:00', '23 16:00', //
        '23 18:00', '23 20:00', '23 22:00',
      ]);
      final ids = {for (final r in plan) r.id};
      expect(ids, hasLength(plan.length));
      expect(
          ids.every((id) =>
              id >= waterReminderIds.first && id <= waterReminderIds.last),
          isTrue);
    });

    test('messages are the five at random, never the same twice in a row', () {
      final plan = planWaterReminders(
          now: _now,
          everyHours: 1,
          from: _eight,
          to: _ten,
          goalReachedToday: false,
          texts: _texts,
          random: Random(7));
      final titles = [for (final r in plan) r.title];
      final known = {for (final m in _texts.messages) m.title};
      expect(known, hasLength(5));
      expect(titles.toSet(), known, reason: 'a week uses all five');
      for (var i = 1; i < titles.length; i++) {
        expect(titles[i], isNot(titles[i - 1]));
      }
      for (final r in plan) {
        expect(_texts.messages, contains((title: r.title, body: r.body)));
      }
      // A week of hourly reminders stays far below Android's 500 alarms.
      expect(plan.length, lessThan(7 * 16));
    });

    test('reaching the goal skips the rest of today', () {
      final plan = planWaterReminders(
          now: _now,
          everyHours: 2,
          from: _eight,
          to: _ten,
          goalReachedToday: true,
          texts: _texts,
          random: Random(1),
          days: 2);
      expect(_hm(plan.first.when), '23 8:00');
      expect(plan, hasLength(8));
    });

    test('an hour and a half apart', () {
      final plan = planWaterReminders(
          now: DateTime(2026, 10, 22, 6),
          everyHours: 1.5,
          from: _eight,
          to: _ten,
          goalReachedToday: false,
          texts: _texts,
          random: Random(1),
          days: 1);
      expect([for (final r in plan) _hm(r.when)].take(3),
          ['22 8:00', '22 9:30', '22 11:00']);
      expect(_hm(plan.last.when), '22 21:30');
      expect(plan, hasLength(10));
    });
  });

  group('controller', () {
    test(
        'settings are kept; a bad window or a refused permission changes '
        'nothing', () async {
      final scheduler = _Scheduler()..allow = false;
      final controller =
          WaterReminderController(scheduler: scheduler, clock: () => _now);
      expect(
          await controller.setEnabled(true,
              texts: _texts, goalReachedToday: false),
          isFalse);
      expect(controller.enabled, isFalse);

      scheduler.allow = true;
      await controller.setEnabled(true, texts: _texts, goalReachedToday: false);
      await controller.setInterval(3, texts: _texts, goalReachedToday: false);
      expect(
          await controller.setWindow(const TimeOfDay(hour: 21, minute: 0),
              const TimeOfDay(hour: 7, minute: 0),
              texts: _texts, goalReachedToday: false),
          isFalse);
      expect(
          await controller.setWindow(const TimeOfDay(hour: 7, minute: 0),
              const TimeOfDay(hour: 21, minute: 0),
              texts: _texts, goalReachedToday: false),
          isTrue);
      expect(_hm(scheduler.scheduled!.first.when), '22 10:00');
      expect(
          scheduler.scheduled![1].when
              .difference(scheduler.scheduled!.first.when),
          const Duration(hours: 3));

      final again = WaterReminderController(scheduler: _Scheduler());
      await again.load();
      expect(again.enabled, isTrue);
      expect(again.everyHours, 3);
      expect(again.from, const TimeOfDay(hour: 7, minute: 0));
      expect(again.to, const TimeOfDay(hour: 21, minute: 0));
    });

    test('turning off cancels only the water reminders', () async {
      final scheduler = _Scheduler();
      final controller =
          WaterReminderController(scheduler: scheduler, clock: () => _now);
      await controller.setEnabled(true, texts: _texts, goalReachedToday: false);
      expect(scheduler.scheduled, isNotEmpty);
      await controller.setEnabled(false,
          texts: _texts, goalReachedToday: false);
      expect(scheduler.scheduled, isNull);
      expect(scheduler.cancelled, 1);
      // The meal ones are another id range, cancelled on their own.
      expect(mealReminderIds.last, lessThan(waterReminderIds.first));
    });
  });

  testWidgets('the settings card turns reminders on and changes the interval',
      (tester) async {
    tester.view.physicalSize = const Size(400, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scheduler = _Scheduler();
    final water =
        WaterReminderController(scheduler: scheduler, clock: () => _now);
    final meals = _MealScheduler();
    await tester.pumpWidget(localizedApp(
      home: Scaffold(
        body: SettingsScreen(
          themeController: ThemeController(),
          localeController: LocaleController(),
          reminders: ReminderController(scheduler: meals),
          waterReminders: water,
          database: _Database(2000),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Nhắc uống nước'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('water-reminders-switch')));
    await tester.pumpAndSettle();
    expect(water.enabled, isTrue);
    // 2,000 ml drunk already: today is done, tomorrow starts at 8:00.
    expect(_hm(scheduler.scheduled!.first.when), '23 8:00');

    await tester.tap(find.byKey(const ValueKey('water-every-4.0')));
    await tester.pumpAndSettle();
    expect(water.everyHours, 4);
    expect([for (final r in scheduler.scheduled!.take(5)) _hm(r.when)],
        ['23 8:00', '23 12:00', '23 16:00', '23 20:00', '24 8:00']);
    expect(find.text('1,5 tiếng'), findsOneWidget);
    expect(meals.cancelled, 0, reason: 'meal reminders are left alone');
  });
}
