import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/account_settings.dart';

/// Label the app reports for its own session, e.g. "iPhone 15 Pro - DealGo" or "Samsung Galaxy S24 - DealGo".
import 'dart:io' show Platform;

bool get _isTesting {
  try {
    return Platform.environment.containsKey('FLUTTER_TEST');
  } catch (_) {
    return false;
  }
}

/// Sanitizes a string so it is strictly valid printable ASCII (32..126) for HTTP header values.
String toHeaderSafeAscii(String value, {String fallback = 'DealGo-App'}) {
  final normalized = value
      .replaceAll('·', '-')
      .replaceAll('•', '-')
      .replaceAll('—', '-')
      .replaceAll('–', '-');
  final buffer = StringBuffer();
  for (final codeUnit in normalized.codeUnits) {
    if (codeUnit >= 32 && codeUnit <= 126) {
      buffer.writeCharCode(codeUnit);
    }
  }
  final result = buffer.toString().trim();
  return result.isNotEmpty ? result : fallback;
}

/// Label the app reports for its own session, e.g. "iPhone 15 Pro - DealGo" or "Samsung Galaxy S24 - DealGo".
Future<String> currentDeviceLabel() async {
  final os = switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iOS',
    TargetPlatform.macOS => 'macOS',
    TargetPlatform.windows => 'Windows',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.fuchsia => 'Fuchsia',
  };

  if (_isTesting) {
    return '$os - DealGo';
  }

  try {
    final plugin = DeviceInfoPlugin();
    if (kIsWeb) {
      final web = await plugin.webBrowserInfo.timeout(
        const Duration(milliseconds: 500),
      );
      return '${web.browserName.name} - Web';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = await plugin.androidInfo.timeout(
        const Duration(milliseconds: 500),
      );
      final brand = android.brand.trim();
      final model = android.model.trim();
      final name = model.toLowerCase().startsWith(brand.toLowerCase())
          ? model
          : (brand.isNotEmpty ? '$brand $model' : model);
      if (name.isNotEmpty) return '$name - DealGo';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = await plugin.iosInfo.timeout(
        const Duration(milliseconds: 500),
      );
      final model = ios.modelName.isNotEmpty
          ? ios.modelName
          : (ios.name.isNotEmpty ? ios.name : ios.model);
      final trimmed = model.trim();
      if (trimmed.isNotEmpty) return '$trimmed - DealGo';
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      final mac = await plugin.macOsInfo.timeout(
        const Duration(milliseconds: 500),
      );
      final model = mac.model.trim();
      if (model.isNotEmpty) return '$model - DealGo';
    }
  } catch (_) {
    // Fallback in widget tests or headless environments
  }

  return '$os - DealGo';
}

/// Operating system guessed from the client label or User-Agent.
String? sessionOs(AccountSession s) {
  final text = '${s.deviceLabel ?? ''} ${s.userAgent ?? ''}'.toLowerCase();
  if (text.contains('android') ||
      text.contains('samsung') ||
      text.contains('pixel') ||
      text.contains('xiaomi') ||
      text.contains('oppo')) {
    return 'Android';
  }
  if (text.contains('iphone') ||
      text.contains('ipad') ||
      text.contains('ios')) {
    return 'iOS';
  }
  if (text.contains('mac os') ||
      text.contains('macos') ||
      text.contains('macintosh') ||
      text.contains('macbook')) {
    return 'macOS';
  }
  if (text.contains('windows')) return 'Windows';
  if (text.contains('linux')) return 'Linux';
  return null;
}

String? _browser(String? userAgent) {
  final ua = (userAgent ?? '').toLowerCase();
  if (ua.isEmpty) return null;
  if (ua.contains('edg/')) return 'Edge';
  if (ua.contains('firefox')) return 'Firefox';
  if (ua.contains('chrome') || ua.contains('crios')) return 'Chrome';
  if (ua.contains('safari')) return 'Safari';
  return null;
}

bool sessionIsMobile(AccountSession s) {
  final text = '${s.deviceLabel ?? ''} ${s.userAgent ?? ''}'.toLowerCase();
  if (text.contains('iphone') ||
      text.contains('ipad') ||
      text.contains('android') ||
      text.contains('mobile')) {
    return true;
  }
  final os = sessionOs(s);
  return os == 'Android' || os == 'iOS';
}

/// Headline for a session row: the client device name or "OS · Browser".
String sessionTitle(AppLocalizations l10n, AccountSession s) {
  if (s.channel == 'OPS') return l10n.sessionsAdminWeb;
  final label = (s.deviceLabel ?? '').trim();
  if (label.isNotEmpty) return label;
  final parts = [sessionOs(s), _browser(s.userAgent)].whereType<String>();
  if (parts.isNotEmpty) return parts.join(' · ');
  return l10n.sessionsUnknownDevice;
}

IconData sessionIcon(AccountSession s) {
  if (s.channel == 'OPS') return DealGoIcons.laptop;
  if (sessionIsMobile(s)) return DealGoIcons.smartphone;
  if (sessionOs(s) != null) return DealGoIcons.laptop;
  return DealGoIcons.devices;
}

/// Human-friendly network / location string from IP address.
String formatSessionLocation(String? ipAddress) {
  final ip = (ipAddress ?? '').trim();
  if (ip.isEmpty) return '';
  if (ip == '127.0.0.1' || ip == '::1' || ip == 'localhost') {
    return 'Mạng nội bộ (127.0.0.1)';
  }
  if (ip.startsWith('192.168.') ||
      ip.startsWith('10.') ||
      ip.startsWith('172.16.')) {
    return 'Wi-Fi / Mạng riêng ($ip)';
  }
  return 'IP: $ip';
}
