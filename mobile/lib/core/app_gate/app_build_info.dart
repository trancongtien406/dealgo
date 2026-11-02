import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// t82u: this install's platform + build number, sent as `X-App-Platform` /
/// `X-App-Build` so the API can enforce the minimum build (DEC-PROD-089).
///
/// Filled once at startup ([load]); until then (and on web / desktop) no
/// headers are sent and the server never blocks.
class AppBuildInfo {
  AppBuildInfo({this.platform, this.build});

  String? platform;
  int? build;

  bool get known => platform != null && build != null;

  Map<String, String> get headers =>
      known ? {'X-App-Platform': platform!, 'X-App-Build': '$build'} : const {};

  static String? currentPlatform() {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => null,
    };
  }

  Future<void> load() async {
    if (known) return;
    final platform = currentPlatform();
    if (platform == null) return;
    try {
      final info = await PackageInfo.fromPlatform();
      final build = int.tryParse(info.buildNumber.trim());
      if (build == null) return;
      this.platform = platform;
      this.build = build;
    } on Object {
      // No plugin (tests) — stay unknown; nothing is enforced.
    }
  }
}
