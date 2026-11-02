import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design_system/tokens/dealgo_tokens.dart';

/// How the app chooses light or dark surfaces.
enum AppThemeChoice {
  system,
  light,
  dark;

  static AppThemeChoice fromStored(String? raw) => switch (raw) {
    'light' => AppThemeChoice.light,
    'dark' => AppThemeChoice.dark,
    'system' => AppThemeChoice.system,
    _ => AppThemeChoice.light,
  };

  String get stored => name;
}

/// Device language and appearance. Not part of the account on the server.
///
/// Language with no saved choice stays Vietnamese (the product baseline).
/// Appearance with no saved choice is light.
class AppAppearance extends ChangeNotifier {
  AppAppearance({
    Locale locale = const Locale('vi'),
    this.themeChoice = AppThemeChoice.light,
  }) : _locale = _supported(locale);

  static const localeKey = 'dealgo.locale';
  static const themeKey = 'dealgo.themeMode';
  static const supportedLocales = [Locale('vi'), Locale('en')];

  /// Values read at startup, copied into each [AppAppearance].
  static Locale warmedLocale = const Locale('vi');
  static AppThemeChoice warmedTheme = AppThemeChoice.light;

  Locale _locale;
  AppThemeChoice themeChoice;

  Locale get locale => _locale;

  ThemeMode get themeMode => switch (themeChoice) {
    AppThemeChoice.system => ThemeMode.system,
    AppThemeChoice.light => ThemeMode.light,
    AppThemeChoice.dark => ThemeMode.dark,
  };

  Brightness brightness(Brightness platform) => switch (themeChoice) {
    AppThemeChoice.light => Brightness.light,
    AppThemeChoice.dark => Brightness.dark,
    AppThemeChoice.system => platform,
  };

  /// Applies the resolved palette. Call before building widgets that read
  /// [DealGoColors].
  void applyPalette(Brightness platform) {
    DealGoPalette.use(brightness(platform));
  }

  Future<void> setLocale(Locale locale) async {
    final next = _supported(locale);
    if (next == _locale) return;
    _locale = next;
    warmedLocale = next;
    notifyListeners();
    final prefs = await _prefs();
    await prefs?.setString(localeKey, next.languageCode);
  }

  Future<void> setTheme(AppThemeChoice theme) async {
    if (theme == themeChoice) return;
    themeChoice = theme;
    warmedTheme = theme;
    notifyListeners();
    final prefs = await _prefs();
    await prefs?.setString(themeKey, theme.stored);
  }

  static Future<void> warmUp() async {
    final prefs = await _prefs();
    final code = prefs?.getString(localeKey);
    warmedLocale = code == null ? const Locale('vi') : _supported(Locale(code));
    warmedTheme = AppThemeChoice.fromStored(prefs?.getString(themeKey));
  }

  static AppAppearance fromWarmup() =>
      AppAppearance(locale: warmedLocale, themeChoice: warmedTheme);

  /// Tests only.
  static void resetForTest() {
    warmedLocale = const Locale('vi');
    warmedTheme = AppThemeChoice.light;
    DealGoPalette.use(Brightness.light);
  }

  static Locale _supported(Locale locale) {
    for (final supported in supportedLocales) {
      if (supported.languageCode == locale.languageCode) return supported;
    }
    return const Locale('vi');
  }

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }
}
