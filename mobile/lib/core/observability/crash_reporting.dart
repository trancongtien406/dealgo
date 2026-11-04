import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Flutter flavor from `--flavor` or the Xcode `dev` / `prod` scheme.
const _flavor = String.fromEnvironment('FLUTTER_APP_FLAVOR');

/// Public client DSN of the DealGo mobile Sentry project. It can only submit
/// events, so it ships in the app like any Sentry client key.
const dealGoMobileSentryDsn =
    'https://0908d4b63d3c020d192acffa68c870de@o4512373110603776.ingest.de.sentry.io/4512373234597968';

/// DEC-PROD-054: flavored (`dev`/`prod`) and release builds report to
/// [dealGoMobileSentryDsn]; un-flavored debug runs and `flutter test` report
/// nothing. `--dart-define=SENTRY_DSN=` (empty) turns it off for a build.
const sentryDsn = String.fromEnvironment(
  'SENTRY_DSN',
  defaultValue: _flavor != '' || kReleaseMode ? dealGoMobileSentryDsn : '',
);

/// `dev` / `prod`, from the flavor (release builds without one count as prod).
const sentryEnvironment = String.fromEnvironment(
  'SENTRY_ENVIRONMENT',
  defaultValue: _flavor == 'prod' || (_flavor == '' && kReleaseMode)
      ? 'prod'
      : 'dev',
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
///
/// Sentry hooks `FlutterError.onError`, `PlatformDispatcher.onError` and the
/// native iOS/Android crash handlers; the release is
/// `<bundle id>@<version>+<build>` read from the app.
Future<void> runWithCrashReporting(Future<void> Function() appRunner) async {
  if (!isCrashReportingEnabled()) {
    await appRunner();
    return;
  }
  // The zone catches async errors that escape both Flutter hooks; it wraps
  // init so the binding and runApp share one zone.
  await runZonedGuarded(
    () => SentryFlutter.init((options) {
      options.dsn = sentryDsn.trim();
      options.environment = sentryEnvironment;
      options.tracesSampleRate = parseTracesSampleRate(_sentryTracesSampleRate);
      options.sendDefaultPii = false;
      // Debug prints carry (redacted) HTTP logs; keep them on the device.
      options.enablePrintBreadcrumbs = false;
      options.beforeSend = (event, hint) =>
          isExpectedTransportClose(event) ? null : scrubEvent(event);
    }, appRunner: appRunner),
    _reportZoneError,
  );
}

void _reportZoneError(Object error, StackTrace stack) {
  unawaited(Sentry.captureException(error, stackTrace: stack));
}

/// The realtime WebSocket closing (app backgrounded, network switch) is
/// expected: socket.io reconnects and feeds re-GET on resume. Not a bug, so
/// it is dropped instead of becoming a Sentry issue.
@visibleForTesting
bool isExpectedTransportClose(SentryEvent event) {
  final original = event.throwable;
  final names = <String>[
    if (original != null) original.runtimeType.toString(),
    for (final e in event.exceptions ?? const <SentryException>[]) ...[
      e.type ?? '',
      e.value ?? '',
    ],
  ].join(' ');
  return names.contains('WebSocketConnectionClosed') ||
      names.contains('WebSocketChannelException') && names.contains('closed');
}

final _urlQuery = RegExp(r'(https?://[^\s?]+)\?[^\s]*');

/// Keeps only the user id, drops request details and strips URL queries
/// (search text, tokens) from exception messages.
@visibleForTesting
SentryEvent scrubEvent(SentryEvent event) {
  final id = event.user?.id;
  event.user = id == null ? null : SentryUser(id: id);
  event.request = null;
  for (final exception in event.exceptions ?? const <SentryException>[]) {
    exception.value = exception.value?.replaceAllMapped(
      _urlQuery,
      (m) => m[1]!,
    );
  }
  return event;
}

/// Tags later events with the signed-in user's id (nothing else), or clears it.
void setCrashReportingUser(String? userId) {
  unawaited(
    Future.sync(
      () => Sentry.configureScope(
        (scope) =>
            scope.setUser(userId == null ? null : SentryUser(id: userId)),
      ),
    ),
  );
}

/// Reports a failure the app caught and turned into a friendly message.
/// [fingerprint] groups reports that share a stack (e.g. one per endpoint).
void reportHandledError(
  Object error, {
  StackTrace? stack,
  List<String>? fingerprint,
}) {
  unawaited(
    Sentry.captureException(
      error,
      stackTrace: stack ?? StackTrace.current,
      withScope: fingerprint == null
          ? null
          : (scope) => scope.fingerprint = fingerprint,
    ),
  );
}

final _idSegment = RegExp(r'^(?:\d+|[0-9a-fA-F-]{16,}|[A-Za-z0-9_-]{20,})$');

/// [path] without its query and with ids/tokens replaced by `:id`, so
/// breadcrumbs and grouping never carry identifiers or share tokens.
String redactPath(String path) {
  final noQuery = path.split('?').first;
  return noQuery
      .split('/')
      .map((part) => _idSegment.hasMatch(part) ? ':id' : part)
      .join('/');
}

/// Navigation breadcrumb between two router locations (paths redacted).
void recordNavigation(String from, String to) {
  unawaited(
    Sentry.addBreadcrumb(
      Breadcrumb(
        category: 'navigation',
        type: 'navigation',
        data: {'from': redactPath(from), 'to': redactPath(to)},
      ),
    ),
  );
}
