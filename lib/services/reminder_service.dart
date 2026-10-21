import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/food_log_entry.dart';

/// Meals that get a reminder, with their default times.
const reminderDefaults = {
  MealSlot.breakfast: TimeOfDay(hour: 8, minute: 0),
  MealSlot.lunch: TimeOfDay(hour: 12, minute: 30),
  MealSlot.dinner: TimeOfDay(hour: 19, minute: 30),
};

/// One daily notification: its meal, time and text in the app's language.
class MealReminder {
  const MealReminder({
    required this.meal,
    required this.time,
    required this.title,
    required this.body,
  });

  final MealSlot meal;
  final TimeOfDay time;
  final String title;
  final String body;
}

/// Shows the notifications; tests swap in a fake.
abstract class ReminderScheduler {
  /// Asks Android 13+ for permission to notify; true when allowed.
  Future<bool> requestPermission();

  /// Replaces every scheduled reminder with [reminders], repeating daily.
  Future<void> schedule(List<MealReminder> reminders,
      {required String channelName});

  Future<void> cancelAll();
}

/// Daily local notifications through flutter_local_notifications, scheduled
/// inexactly: they may come a few minutes late, but need no exact-alarm
/// permission and nothing is sent over the network.
class LocalReminderScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  Future<void> _init() => _ready ??= () async {
        tz_data.initializeTimeZones();
        try {
          final zone = await FlutterTimezone.getLocalTimezone();
          tz.setLocalLocation(tz.getLocation(zone.identifier));
        } catch (_) {
          tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
        }
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          ),
        );
      }();

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> requestPermission() async {
    await _init();
    return await _android?.requestNotificationsPermission() ?? true;
  }

  @override
  Future<void> schedule(List<MealReminder> reminders,
      {required String channelName}) async {
    await _init();
    await _plugin.cancelAll();
    final now = tz.TZDateTime.now(tz.local);
    for (final reminder in reminders) {
      var when = tz.TZDateTime(tz.local, now.year, now.month, now.day,
          reminder.time.hour, reminder.time.minute);
      if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        id: 100 + reminder.meal.index,
        scheduledDate: when,
        title: reminder.title,
        body: reminder.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails('meal_reminders', channelName),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    await _init();
    await _plugin.cancelAll();
  }
}

/// Whether meal reminders are on and at what times, kept on the device.
class ReminderController extends ChangeNotifier {
  ReminderController({ReminderScheduler? scheduler})
      : _scheduler = scheduler ?? LocalReminderScheduler();

  final ReminderScheduler _scheduler;
  bool _enabled = false;
  final Map<MealSlot, TimeOfDay> _times = Map.of(reminderDefaults);

  bool get enabled => _enabled;
  Map<MealSlot, TimeOfDay> get times => Map.unmodifiable(_times);

  static const _enabledKey = 'reminders_enabled';
  static String _timeKey(MealSlot meal) => 'reminder_${meal.name}';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? false;
      for (final meal in reminderDefaults.keys) {
        final saved = prefs.getString(_timeKey(meal));
        final parts = saved?.split(':');
        if (parts != null && parts.length == 2) {
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          if (hour != null && minute != null) {
            _times[meal] = TimeOfDay(hour: hour, minute: minute);
          }
        }
      }
    } catch (_) {
      // Defaults stay.
    }
    notifyListeners();
  }

  /// Turns reminders on or off; [texts] gives each meal's title and body in
  /// the current language. Returns false when Android refused permission.
  Future<bool> setEnabled(bool value,
      {required ({String title, String body}) Function(MealSlot) texts,
      required String channelName}) async {
    if (value && !await _scheduler.requestPermission()) return false;
    _enabled = value;
    await _save();
    await _apply(texts, channelName);
    notifyListeners();
    return true;
  }

  Future<void> setTime(MealSlot meal, TimeOfDay time,
      {required ({String title, String body}) Function(MealSlot) texts,
      required String channelName}) async {
    _times[meal] = time;
    await _save();
    await _apply(texts, channelName);
    notifyListeners();
  }

  Future<void> _apply(({String title, String body}) Function(MealSlot) texts,
      String channelName) async {
    if (!_enabled) {
      await _scheduler.cancelAll();
      return;
    }
    await _scheduler.schedule([
      for (final entry in _times.entries)
        MealReminder(
          meal: entry.key,
          time: entry.value,
          title: texts(entry.key).title,
          body: texts(entry.key).body,
        ),
    ], channelName: channelName);
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, _enabled);
      for (final entry in _times.entries) {
        await prefs.setString(
            _timeKey(entry.key), '${entry.value.hour}:${entry.value.minute}');
      }
    } catch (error) {
      debugPrint('Could not save reminder settings: $error');
    }
  }
}
