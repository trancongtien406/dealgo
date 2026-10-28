import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// App Review 2.5.4: only declare the `location` background mode when the app
/// really tracks in background. Today tracking is foreground-only (no
/// allowBackgroundLocationUpdates anywhere in lib/). The "Always" purpose
/// string stays: the linked location plugin references that API and App Store
/// Connect rejects the upload without it (ITMS-90683).
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
        RegExp(
          r'UIBackgroundModes</key>\s*<array>[^<]*(<string>[^<]*</string>\s*)*<string>location</string>',
        ).hasMatch(plist),
        isFalse,
      );
    }
    expect(plist.contains('NSLocationWhenInUseUsageDescription'), isTrue);
  });
}
