import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Sends today's numbers to the Android home-screen widget
/// (android/app/src/main/java/.../TodayWidgetProvider.kt). Does nothing on
/// other platforms and in tests; a failure only leaves the widget stale.
abstract final class HomeWidgetSync {
  static const _provider = 'io.github.jimeavv.optifit.TodayWidgetProvider';

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  static Future<void> update({
    required String title,
    required String calories,
    required String water,
    required String streak,
  }) async {
    if (!_supported) return;
    try {
      await HomeWidget.saveWidgetData<String>('title', title);
      await HomeWidget.saveWidgetData<String>('calories', calories);
      await HomeWidget.saveWidgetData<String>('water', water);
      await HomeWidget.saveWidgetData<String>('streak', streak);
      await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
    } catch (error) {
      debugPrint('Home widget not updated: $error');
    }
  }
}
