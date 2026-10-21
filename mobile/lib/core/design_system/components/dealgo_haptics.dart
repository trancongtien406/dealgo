import 'package:flutter/services.dart';

/// Thin haptics facade so feedback stays consistent and easy to mute.
abstract final class DealGoHaptics {
  /// Taps on primary CTAs and toggles.
  static void tap() => HapticFeedback.lightImpact();

  /// Picker / segmented / chip selection changes.
  static void selection() => HapticFeedback.selectionClick();

  /// A flow completed (order placed, OTP verified, trip completed).
  static void success() => HapticFeedback.mediumImpact();

  /// Blocking validation or request failure.
  static void error() => HapticFeedback.heavyImpact();
}
