import 'dart:async';

import 'package:dealgo/features/driver/presentation/widgets/incoming_job_alert.dart';
import 'package:dealgo/features/driver/presentation/widgets/ride_view_beacon.dart';
import 'package:dealgo/features/inbox/presentation/inbox_unread.dart';
import 'package:flutter_test/flutter_test.dart';

/// App-wide singletons start clean in every test.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(InboxUnread.instance.resetForTest);
  setUp(() => IncomingJobAlertHost.enabled = false);
  setUp(() => RideViewBeacon.enabled = false);
  await testMain();
}
