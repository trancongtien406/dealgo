import 'package:dealgo/core/analytics/console_analytics.dart';
import 'package:dealgo/core/analytics/noop_analytics.dart';
import 'package:dealgo/core/deeplink/deep_link_parser.dart';
import 'package:dealgo/core/notifications/notification_router.dart';
import 'package:dealgo/core/push/fake_push.dart';
import 'package:dealgo/core/push/fcm_push.dart';
import 'package:dealgo/firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeepLinkParser', () {
    const parser = DeepLinkParser();

    test('parses dealgo scheme into go_router location', () {
      expect(
        parser.parse(Uri.parse('dealgo://customer/home')),
        '/customer/home',
      );
      expect(
        parser.parse(Uri.parse('dealgo://customer/food/cart?x=1')),
        '/customer/food/cart?x=1',
      );
    });

    test('parses https app links under /app on the unified host', () {
      expect(
        parser.parse(
          Uri.parse('https://dealgo.trancongtien.com/app/driver/jobs?x=1'),
        ),
        '/driver/jobs?x=1',
      );
      expect(
        parser.parse(
          Uri.parse('https://www.dealgo.trancongtien.com/app/customer/home'),
        ),
        '/customer/home',
      );
      expect(
        parser.parse(Uri.parse('https://dealgo.trancongtien.com/privacy')),
        isNull,
      );
      expect(
        parser.parse(Uri.parse('http://dealgo.trancongtien.com/app/x')),
        isNull,
      );
      expect(
        const DeepLinkParser(host: 'staging.dealgo.vn')
            .parse(Uri.parse('https://staging.dealgo.vn/app/customer/home')),
        '/customer/home',
      );
    });

    test('rejects unknown hosts', () {
      expect(parser.parse(Uri.parse('https://evil.example/x')), isNull);
    });
  });

  test('NotificationRouter no-ops until navigator bound', () {
    final router = NotificationRouter();
    router.openPath('/customer/home');
    final seen = <String>[];
    router.bindNavigator(seen.add);
    router.openPath('/customer/home');
    router.openPath('relative');
    expect(seen, ['/customer/home']);
  });

  test('FakePush still registers without network', () async {
    final push = FakePush();
    await push.ensureRegistered(accessToken: 'tok');
    expect(await push.currentToken(), 'fake-fcm-token');
  });

  test('pushPlatformName is lowercase ios/android style', () {
    final name = pushPlatformName();
    expect(
      name,
      anyOf('android', 'ios', 'macos', 'linux', 'windows', 'fuchsia'),
    );
    expect(name, equals(name.toLowerCase()));
    expect(name.contains('.'), isFalse);
  });

  test('DefaultFirebaseOptions android and ios stay distinct', () {
    expect(
      DefaultFirebaseOptions.android.appId,
      isNot(DefaultFirebaseOptions.ios.appId),
    );
    expect(DefaultFirebaseOptions.android.appId, contains(':android:'));
    expect(DefaultFirebaseOptions.ios.appId, contains(':ios:'));

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(
      DefaultFirebaseOptions.currentPlatform.appId,
      DefaultFirebaseOptions.android.appId,
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(
      DefaultFirebaseOptions.currentPlatform.appId,
      DefaultFirebaseOptions.ios.appId,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  test('Analytics ports are callable', () async {
    await const NoopAnalytics().logEvent('x');
    await const ConsoleAnalytics().logEvent('y', parameters: {'a': 1});
  });
}
