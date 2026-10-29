import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_localizations.dart';
import 'local_notifications.dart';

/// How often a water reminder may come, in hours.
const waterReminderIntervals = [1.0, 1.5, 2.0, 3.0, 4.0];

/// Days of reminders scheduled ahead. Each one has its own message, so they
/// cannot repeat by themselves; opening the app schedules the next days.
const waterReminderDays = 7;

/// Notification ids of the water reminders, apart from the meal ones.
const waterReminderIds = (first: 1000, last: 1999);

/// One water notification: when it comes and what it says.
class WaterReminder {
  const WaterReminder({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
  });

  final int id;
  final DateTime when;
  final String title;
  final String body;
}

/// The messages to pick from and the Android channel name, in the app's
/// language.
class WaterReminderTexts {
  const WaterReminderTexts({required this.messages, required this.channelName});

  factory WaterReminderTexts.of(AppLocalizations l10n) => WaterReminderTexts(
        messages: [
          (title: l10n.waterReminder1Title, body: l10n.waterReminder1Body),
          (title: l10n.waterReminder2Title, body: l10n.waterReminder2Body),
          (title: l10n.waterReminder3Title, body: l10n.waterReminder3Body),
          (title: l10n.waterReminder4Title, body: l10n.waterReminder4Body),
          (title: l10n.waterReminder5Title, body: l10n.waterReminder5Body),
        ],
        channelName: l10n.waterReminderChannel,
      );

  final List<({String title, String body})> messages;
  final String channelName;
}

/// Every [everyHours] from [from] to [to] (both included), for [days] days
/// starting today, after [now]. Today is left out once [goalReachedToday].
/// Each reminder gets a message at random, never the same one twice in a
/// row.
List<WaterReminder> planWaterReminders({
  required DateTime now,
  required double everyHours,
  required TimeOfDay from,
  required TimeOfDay to,
  required bool goalReachedToday,
  required WaterReminderTexts texts,
  required Random random,
  int days = waterReminderDays,
}) {
  final step = Duration(minutes: (everyHours * 60).round());
  final reminders = <WaterReminder>[];
  int? last;
  for (var day = goalReachedToday ? 1 : 0; day < days; day++) {
    final end =
        DateTime(now.year, now.month, now.day + day, to.hour, to.minute);
    for (var when = DateTime(
            now.year, now.month, now.day + day, from.hour, from.minute);
        !when.isAfter(end);
        when = when.add(step)) {
      if (!when.isAfter(now)) continue;
      var pick = random.nextInt(texts.messages.length);
      if (pick == last && texts.messages.length > 1) {
        pick = (pick + 1 + random.nextInt(texts.messages.length - 1)) %
            texts.messages.length;
      }
      last = pick;
      reminders.add(WaterReminder(
        id: waterReminderIds.first + reminders.length,
        when: when,
        title: texts.messages[pick].title,
        body: texts.messages[pick].body,
      ));
    }
  }
  return reminders;
}

/// Shows the notifications; tests swap in a fake.
abstract class WaterReminderScheduler {
  Future<bool> requestPermission();

  /// Replaces every scheduled water reminder with [reminders].
  Future<void> schedule(List<WaterReminder> reminders,
      {required String channelName});

  /// Cancels every water reminder; meal reminders stay.
  Future<void> cancelAll();
}

/// One-off local notifications, scheduled inexactly like the meal ones.
class LocalWaterReminderScheduler implements WaterReminderScheduler {
  final _notifications = LocalNotifications.instance;

  @override
  Future<bool> requestPermission() => _notifications.requestPermission();

  @override
  Future<void> schedule(List<WaterReminder> reminders,
      {required String channelName}) async {
    await cancelAll();
    for (final reminder in reminders) {
      await _notifications.plugin.zonedSchedule(
        id: reminder.id,
        scheduledDate: tz.TZDateTime.from(reminder.when, tz.local),
        title: reminder.title,
        body: reminder.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails('water_reminders', channelName),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancelAll() =>
      _notifications.cancelRange(waterReminderIds.first, waterReminderIds.last);
}

/// Whether water reminders are on, how often and between which hours, kept
/// on the device.
class WaterReminderController extends ChangeNotifier {
  WaterReminderController(
      {WaterReminderScheduler? scheduler,
      DateTime Function()? clock,
      Random? random})
      : _scheduler = scheduler ?? LocalWaterReminderScheduler(),
        _clock = clock ?? DateTime.now,
        _random = random ?? Random();

  final WaterReminderScheduler _scheduler;
  final DateTime Function() _clock;
  final Random _random;

  bool _enabled = false;
  double _everyHours = 2;
  TimeOfDay _from = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 22, minute: 0);

  bool get enabled => _enabled;
  double get everyHours => _everyHours;
  TimeOfDay get from => _from;
  TimeOfDay get to => _to;

  static const _enabledKey = 'water_reminders_enabled';
  static const _everyKey = 'water_reminder_every_hours';
  static const _fromKey = 'water_reminder_from';
  static const _toKey = 'water_reminder_to';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? false;
      final every = prefs.getDouble(_everyKey);
      if (every != null && waterReminderIntervals.contains(every)) {
        _everyHours = every;
      }
      _from = _parse(prefs.getString(_fromKey)) ?? _from;
      _to = _parse(prefs.getString(_toKey)) ?? _to;
    } catch (_) {
      // Defaults stay.
    }
    notifyListeners();
  }

  static TimeOfDay? _parse(String? saved) {
    final parts = saved?.split(':');
    if (parts == null || parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Turns the reminders on or off. Returns false when Android refused
  /// permission. [goalReachedToday] skips the rest of today.
  Future<bool> setEnabled(bool value,
      {required WaterReminderTexts texts,
      required bool goalReachedToday}) async {
    if (value && !await _scheduler.requestPermission()) return false;
    _enabled = value;
    await _save();
    await refresh(texts: texts, goalReachedToday: goalReachedToday);
    notifyListeners();
    return true;
  }

  Future<void> setInterval(double hours,
      {required WaterReminderTexts texts,
      required bool goalReachedToday}) async {
    _everyHours = hours;
    await _save();
    await refresh(texts: texts, goalReachedToday: goalReachedToday);
    notifyListeners();
  }

  /// Sets the hours reminders may come in. Returns false, changing nothing,
  /// when [to] is not after [from].
  Future<bool> setWindow(TimeOfDay from, TimeOfDay to,
      {required WaterReminderTexts texts,
      required bool goalReachedToday}) async {
    if (to.hour * 60 + to.minute <= from.hour * 60 + from.minute) return false;
    _from = from;
    _to = to;
    await _save();
    await refresh(texts: texts, goalReachedToday: goalReachedToday);
    notifyListeners();
    return true;
  }

  /// Schedules the next [waterReminderDays] days again: when the app opens,
  /// when water is logged (reaching the goal ends today's reminders) and
  /// after a setting changes.
  Future<void> refresh(
      {required WaterReminderTexts texts, required bool goalReachedToday}) {
    // One at a time: two overlapping runs could each cancel before the
    // other schedules, leaving some reminders twice.
    return _queue = _queue
        .then((_) => _apply(texts: texts, goalReachedToday: goalReachedToday));
  }

  Future<void> _queue = Future.value();

  Future<void> _apply(
      {required WaterReminderTexts texts,
      required bool goalReachedToday}) async {
    try {
      if (!_enabled) {
        await _scheduler.cancelAll();
        return;
      }
      await _scheduler.schedule(
        planWaterReminders(
          now: _clock(),
          everyHours: _everyHours,
          from: _from,
          to: _to,
          goalReachedToday: goalReachedToday,
          texts: texts,
          random: _random,
        ),
        channelName: texts.channelName,
      );
    } catch (error) {
      // A reminder that cannot be scheduled must not break logging water.
      debugPrint('Could not schedule water reminders: $error');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, _enabled);
      await prefs.setDouble(_everyKey, _everyHours);
      await prefs.setString(_fromKey, '${_from.hour}:${_from.minute}');
      await prefs.setString(_toKey, '${_to.hour}:${_to.minute}');
    } catch (error) {
      debugPrint('Could not save water reminder settings: $error');
    }
  }
}
