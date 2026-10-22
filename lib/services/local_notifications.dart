import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// The one notifications plugin the meal and water reminders share, set up
/// once with the phone's time zone.
class LocalNotifications {
  LocalNotifications._();

  static final instance = LocalNotifications._();

  final plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  Future<void> ready() => _ready ??= () async {
        tz_data.initializeTimeZones();
        try {
          final zone = await FlutterTimezone.getLocalTimezone();
          tz.setLocalLocation(tz.getLocation(zone.identifier));
        } catch (_) {
          tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
        }
        await plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_stat_notify'),
          ),
        );
      }();

  /// Asks Android 13+ for permission to notify; true when allowed.
  Future<bool> requestPermission() async {
    await ready();
    return await plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission() ??
        true;
  }

  /// Cancels the scheduled notifications whose id is in [first, last], and
  /// leaves the others alone.
  Future<void> cancelRange(int first, int last) async {
    await ready();
    for (final pending in await plugin.pendingNotificationRequests()) {
      if (pending.id >= first && pending.id <= last) {
        await plugin.cancel(id: pending.id);
      }
    }
  }
}
