import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// DEC-PROD-054: crash reporting is opt-in via `--dart-define=SENTRY_DSN=`.
/// Empty → Sentry is never initialised and nothing leaves the device.
const sentryDsn = String.fromEnvironment('SENTRY_DSN');
const sentryEnvironment = String.fromEnvironment(
  'SENTRY_ENVIRONMENT',
  defaultValue: kReleaseMode ? 'production' : 'development',
);
const _sentryTracesSampleRate = String.fromEnvironment(
  'SENTRY_TRACES_SAMPLE_RATE',
  defaultValue: '0',
);

bool isCrashReportingEnabled([String dsn = sentryDsn]) => dsn.trim().isNotEmpty;

double parseTracesSampleRate(String raw) {
  final value = double.tryParse(raw.trim());
  if (value == null || value < 0 || value > 1) {
    return 0;
  }
  return value;
}

/// Runs [appRunner] inside Sentry when a DSN is configured, otherwise directly.
Future<void> runWithCrashReporting(Future<void> Function() appRunner) async {
  if (!isCrashReportingEnabled()) {
    await appRunner();
    return;
  }
  await SentryFlutter.init((options) {
    options.dsn = sentryDsn.trim();
    options.environment = sentryEnvironment;
    options.tracesSampleRate = parseTracesSampleRate(_sentryTracesSampleRate);
    options.sendDefaultPii = false;
  }, appRunner: appRunner);
}
