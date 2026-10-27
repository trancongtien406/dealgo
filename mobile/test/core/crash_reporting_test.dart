import 'package:dealgo/core/observability/crash_reporting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('crash reporting is off without a DSN', () {
    expect(isCrashReportingEnabled(''), isFalse);
    expect(isCrashReportingEnabled('  '), isFalse);
    expect(isCrashReportingEnabled('https://k@o1.ingest.sentry.io/1'), isTrue);
    expect(isCrashReportingEnabled(), isFalse);
  });

  test('runs the app directly when disabled', () async {
    var ran = false;
    await runWithCrashReporting(() async => ran = true);
    expect(ran, isTrue);
  });

  test('clamps the traces sample rate', () {
    expect(parseTracesSampleRate('0.25'), 0.25);
    expect(parseTracesSampleRate('2'), 0);
    expect(parseTracesSampleRate('x'), 0);
  });
}
