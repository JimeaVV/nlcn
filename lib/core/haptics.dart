import 'package:flutter/services.dart';

/// Haptic cues, picked for what Android phones actually play. Many of them
/// skip `HapticFeedback.selectionClick` (CLOCK_TICK), so taps use
/// `lightImpact` (VIRTUAL_KEY) and the big moments use `vibrate`
/// (LONG_PRESS). Every cue follows the phone's own touch-feedback setting.
abstract final class Haptics {
  /// A tick, a chip, a dish choice.
  static void tap() => HapticFeedback.lightImpact();

  /// The model has named the dish.
  static void found() => HapticFeedback.mediumImpact();

  /// The shutter, and a plate logged to the diary.
  static void strong() => HapticFeedback.vibrate();
}
