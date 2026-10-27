import 'package:dealgo/core/notifications/notification_router.dart';
import 'package:dealgo/core/push/fake_push.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tapping a push opens the in-app page the server named.
void main() {
  test('notificationTapPath keeps only in-app absolute paths', () {
    expect(notificationTapPath({'path': '/driver/jobs'}), '/driver/jobs');
    expect(notificationTapPath({'path': '  /driver/jobs '}), '/driver/jobs');
    expect(notificationTapPath({'path': 'https://evil.example'}), isNull);
    expect(notificationTapPath({'path': '//evil.example'}), isNull);
    expect(notificationTapPath({'aggregateType': 'Ride'}), isNull);
    expect(notificationTapPath({'path': 42}), isNull);
  });

  test('NotificationRouter navigates once bound', () {
    final opened = <String>[];
    final router = NotificationRouter()..bindNavigator(opened.add);
    router.openPath(notificationTapPath({'path': '/driver/jobs'}));
    router.openPath(notificationTapPath({'path': 'nope'}));
    expect(opened, ['/driver/jobs']);
  });

  test('FakePush tap listener is a safe no-op', () async {
    await FakePush().listenForTaps((_) => fail('no taps in tests'));
  });
}
