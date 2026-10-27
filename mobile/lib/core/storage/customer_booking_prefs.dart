import 'package:shared_preferences/shared_preferences.dart';

/// Smart defaults for customer booking, kept on this device only.
///
/// Prices are never cached here: the server always re-quotes.
class CustomerBookingPrefs {
  CustomerBookingPrefs._();

  static const _vehicleKey = 'dealgo.lastVehicleClass';
  static const _paymentKey = 'dealgo.lastPaymentMethod';

  /// Only COD/cash exists today; kept so a future method is remembered too.
  static const defaultPaymentMethod = 'CASH';

  static String? _vehicle;
  static String _payment = defaultPaymentMethod;

  static String? get lastVehicleClass => _vehicle;
  static String get lastPaymentMethod => _payment;

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  /// Loads persisted values into memory (call once at startup).
  static Future<void> warmUp() async {
    final prefs = await _prefs();
    _vehicle = prefs?.getString(_vehicleKey) ?? _vehicle;
    _payment = prefs?.getString(_paymentKey) ?? _payment;
  }

  static Future<void> rememberVehicleClass(String? code) async {
    final value = code?.trim();
    if (value == null || value.isEmpty) {
      return;
    }
    _vehicle = value;
    await (await _prefs())?.setString(_vehicleKey, value);
  }

  static Future<void> rememberPaymentMethod(String method) async {
    _payment = method;
    await (await _prefs())?.setString(_paymentKey, method);
  }

  /// Tests only.
  static void resetForTest() {
    _vehicle = null;
    _payment = defaultPaymentMethod;
  }
}
