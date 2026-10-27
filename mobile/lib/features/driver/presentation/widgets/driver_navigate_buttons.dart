import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/motion/dealgo_sheet.dart';
import '../../../../core/navigation/external_navigator.dart';
import '../../../../l10n/app_localizations.dart';

/// One compact "Điều hướng" button for the current stop (DEC-PROD-035).
/// DealGo has no in-app turn-by-turn: guidance is handed to the driver's
/// navigation app. Tapping opens a DealGo bottom sheet listing only the apps
/// this phone has (Google Maps, Apple Maps on iOS, Waze) plus Google Maps web
/// as the always-there fallback. The last pick is listed first.
///
/// When nothing opens the driver gets a snackbar instead of a silent no-op.
class DriverNavigateButtons extends StatelessWidget {
  const DriverNavigateButtons({
    required this.lat,
    required this.lng,
    this.destinationLabel,
    this.platform,
    super.key,
  });

  final double lat;
  final double lng;

  /// "Đến điểm đón" / "Đến điểm trả" … shown under the sheet title.
  final String? destinationLabel;

  /// Overrides [defaultTargetPlatform] (tests / previews).
  final TargetPlatform? platform;

  static const _prefsKey = 'driver.nav.lastApp';

  /// In-memory copy so the order is right even when prefs are unavailable.
  static NavigationApp? _lastChoice;

  static bool _warmed = false;

  @visibleForTesting
  static void resetLastChoice() {
    _lastChoice = null;
    _warmed = false;
  }

  /// Loads the saved pick in the background; the sheet never waits on prefs.
  static void _warmLast() {
    if (_warmed) return;
    _warmed = true;
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final name = prefs.getString(_prefsKey);
        for (final app in NavigationApp.values) {
          if (app.name == name) _lastChoice ??= app;
        }
      } on Object {
        // Prefs are a nicety; never block navigation on them.
      }
    }());
  }

  static void _remember(NavigationApp app) {
    _lastChoice = app;
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, app.name);
      } on Object {
        // best-effort
      }
    }());
  }

  Future<void> _openSheet(BuildContext context) async {
    final navigator = context.read<ExternalNavigator>();
    final os = platform ?? defaultTargetPlatform;
    final available = await navigator.available();
    final last = _lastChoice;
    if (!context.mounted) return;
    final apps = <NavigationApp>[
      for (final app in const [
        NavigationApp.googleMaps,
        NavigationApp.appleMaps,
        NavigationApp.waze,
        NavigationApp.web,
      ])
        if (available.contains(app) &&
            (app != NavigationApp.appleMaps || os == TargetPlatform.iOS))
          app,
    ];
    if (last != null && apps.remove(last)) apps.insert(0, last);
    final picked = await showDealGoSheet<NavigationApp>(
      context: context,
      builder: (sheetContext) => _NavigationSheet(
        apps: apps,
        last: last,
        destinationLabel: destinationLabel,
      ),
    );
    if (picked == null || !context.mounted) return;
    _remember(picked);
    final ok = await navigator.open(picked, lat: lat, lng: lng);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).driverNavOpenFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _warmLast();
    final l10n = AppLocalizations.of(context);
    return Row(
      key: const Key('driver-nav-buttons'),
      children: [
        Expanded(
          child: DealGoSecondaryButton(
            key: const Key('driver-nav-open'),
            label: l10n.driverNavOpen,
            leadingIcon: DealGoIcons.navigation,
            compact: true,
            onPressed: () => _openSheet(context),
          ),
        ),
      ],
    );
  }
}

class _NavigationSheet extends StatelessWidget {
  const _NavigationSheet({
    required this.apps,
    required this.last,
    required this.destinationLabel,
  });

  final List<NavigationApp> apps;
  final NavigationApp? last;
  final String? destinationLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    // The theme draws the single drag handle (bottomSheetTheme.showDragHandle).
    return SafeArea(
      top: false,
      child: Padding(
        key: const Key('driver-nav-sheet'),
        padding: const EdgeInsets.fromLTRB(
          DealGoSpacing.s16,
          0,
          DealGoSpacing.s16,
          DealGoSpacing.s12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.driverNavSheetTitle, style: textTheme.titleMedium),
            if (destinationLabel != null) ...[
              const SizedBox(height: DealGoSpacing.s2),
              Text(
                destinationLabel!,
                style: textTheme.bodySmall?.copyWith(
                  color: DealGoColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: DealGoSpacing.s8),
            for (final app in apps)
              _NavigationAppTile(
                app: app,
                isLast: app == last,
                onTap: () => Navigator.of(context).pop(app),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavigationAppTile extends StatelessWidget {
  const _NavigationAppTile({
    required this.app,
    required this.isLast,
    required this.onTap,
  });

  final NavigationApp app;
  final bool isLast;
  final VoidCallback onTap;

  String _label(AppLocalizations l10n) => switch (app) {
    NavigationApp.googleMaps => l10n.driverNavGoogleMaps,
    NavigationApp.appleMaps => l10n.driverNavAppleMaps,
    NavigationApp.waze => l10n.driverNavWaze,
    NavigationApp.web => l10n.driverNavWeb,
  };

  String get _keyName => switch (app) {
    NavigationApp.googleMaps => 'google',
    NavigationApp.appleMaps => 'apple',
    NavigationApp.waze => 'waze',
    NavigationApp.web => 'web',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: Key('driver-nav-$_keyName'),
      borderRadius: BorderRadius.circular(DealGoRadius.card),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s6),
          child: Row(
            children: [
              NavigationAppGlyph(app: app),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(child: Text(_label(l10n), style: textTheme.bodyLarge)),
              if (isLast)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DealGoSpacing.s8,
                    vertical: DealGoSpacing.s2,
                  ),
                  decoration: BoxDecoration(
                    color: DealGoColors.subtlePurple,
                    borderRadius: BorderRadius.circular(DealGoRadius.pill),
                  ),
                  child: Text(
                    l10n.driverNavLastUsed,
                    style: textTheme.labelSmall?.copyWith(
                      color: DealGoColors.primary,
                    ),
                  ),
                ),
              const SizedBox(width: DealGoSpacing.s4),
              const Icon(
                DealGoIcons.chevronRight,
                size: 20,
                color: DealGoColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logo-like app tiles (not the trademarked artwork): the colours and shape
/// drivers recognise at a glance.
class NavigationAppGlyph extends StatelessWidget {
  const NavigationAppGlyph({required this.app, this.size = 40, super.key});

  final NavigationApp app;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.26);
    switch (app) {
      case NavigationApp.googleMaps:
        return _tile(
          radius: radius,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: radius,
            border: Border.all(color: DealGoColors.border),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 0,
                bottom: 0,
                child: Container(
                  width: size * 0.5,
                  height: size * 0.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFF34A853).withValues(alpha: 0.22),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(size * 0.26),
                    ),
                  ),
                ),
              ),
              Icon(
                DealGoIcons.pinFilled,
                size: size * 0.62,
                color: const Color(0xFFEA4335),
              ),
            ],
          ),
        );
      case NavigationApp.appleMaps:
        return _tile(
          radius: radius,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7ED957), Color(0xFF2F9BFF)],
            ),
          ),
          child: Icon(
            DealGoIcons.navigation,
            size: size * 0.52,
            color: Colors.white,
          ),
        );
      case NavigationApp.waze:
        return _tile(
          radius: radius,
          decoration: BoxDecoration(
            color: const Color(0xFF33CCFF),
            borderRadius: radius,
          ),
          child: Icon(
            Icons.sentiment_satisfied_alt_rounded,
            size: size * 0.6,
            color: Colors.white,
          ),
        );
      case NavigationApp.web:
        return _tile(
          radius: radius,
          decoration: BoxDecoration(
            color: DealGoColors.infoSurface,
            borderRadius: radius,
          ),
          child: Icon(
            Icons.public_rounded,
            size: size * 0.55,
            color: DealGoColors.info,
          ),
        );
    }
  }

  Widget _tile({
    required BorderRadius radius,
    required BoxDecoration decoration,
    required Widget child,
  }) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: radius,
        child: Center(child: child),
      ),
    ),
  );
}
