import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// App Review 2.5.4: only declare the `location` background mode / "Always"
/// string when the app really tracks in background. Today tracking is
/// foreground-only (no allowBackgroundLocationUpdates anywhere in lib/).
void main() {
  test('no unused iOS background-location declarations', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final usesBg = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .any(
          (f) => f.readAsStringSync().contains(
            'allowBackgroundLocationUpdates: true',
          ),
        );
    if (!usesBg) {
      expect(
        plist.contains('NSLocationAlwaysAndWhenInUseUsageDescription'),
        isFalse,
      );
      expect(
        RegExp(
          r'UIBackgroundModes</key>\s*<array>[^<]*(<string>[^<]*</string>\s*)*<string>location</string>',
        ).hasMatch(plist),
        isFalse,
      );
    }
    expect(plist.contains('NSLocationWhenInUseUsageDescription'), isTrue);
  });
}
