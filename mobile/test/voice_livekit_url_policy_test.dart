import 'package:dealgo/features/voice/data/media/livekit_url_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release builds only accept wss://', () {
    assertLiveKitUrlAllowed('wss://livekit.dealgo.vn', isRelease: true);
    expect(
      () => assertLiveKitUrlAllowed('ws://192.168.1.10:7880', isRelease: true),
      throwsStateError,
    );
  });

  test('debug builds also accept ws:// to the local LiveKit', () {
    assertLiveKitUrlAllowed('ws://192.168.1.10:7880', isRelease: false);
    assertLiveKitUrlAllowed('wss://livekit.dealgo.vn', isRelease: false);
  });

  test('rejects non-websocket or empty URLs', () {
    for (final url in ['https://livekit.dealgo.vn', '', 'livekit.dealgo.vn']) {
      expect(
        () => assertLiveKitUrlAllowed(url, isRelease: false),
        throwsStateError,
      );
    }
  });
}
