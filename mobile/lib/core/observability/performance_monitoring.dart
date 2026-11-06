import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

import '../config/app_env.dart';
import 'path_redaction.dart';

/// `true` forces collection on in debug builds; `false` turns it off
/// everywhere. Unset: on for profile/release, off for debug.
const _perfOverride = String.fromEnvironment('PERF_ENABLED');

/// Firebase Performance Monitoring for the Dart side of the app.
///
/// The native SDKs only see their own networking: `dart:io` requests never
/// touch OkHttp/URLSession, so API calls are timed through
/// `PerfHttpInterceptor` and reported as HTTP metrics. Custom traces cover the
/// work the server never sees (cold start, audio session setup).
///
/// Every call is a no-op when Firebase is absent or collection is off, so tests
/// and mock builds never touch the platform channel.
class PerformanceMonitoring {
  PerformanceMonitoring._();

  static final PerformanceMonitoring instance = PerformanceMonitoring._();

  bool _enabled = false;

  /// Collection state of the last [init]; `false` also means "SDK unusable".
  bool get isEnabled => _enabled;

  /// Enables collection once Firebase is up. Soft-fails: telemetry must never
  /// keep the app from starting.
  Future<void> init() async {
    if (kIsWeb || Firebase.apps.isEmpty) {
      return;
    }
    final wanted = _perfOverride.isEmpty
        ? !kDebugMode
        : _perfOverride == 'true';
    try {
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(
        wanted,
      );
      _enabled = wanted;
    } catch (error) {
      debugPrint('Firebase Performance init skipped: $error');
    }
  }

  /// Starts a custom trace; call [PerfTrace.stop] exactly once, from `finally`.
  PerfTrace startTrace(String name) {
    final sanitized = traceName(name);
    if (!_enabled || sanitized == null) {
      return PerfTrace.disabled();
    }
    try {
      final trace = FirebasePerformance.instance.newTrace(sanitized);
      final running = PerfTrace._(trace);
      // One of the five attribute slots, so dev and prod are separable in the
      // console: both flavors report to the same Firebase app.
      running.putAttribute('environment', appEnvironment);
      return running;
    } catch (error) {
      debugPrint('Performance trace "$name" skipped: $error');
      return PerfTrace.disabled();
    }
  }

  /// Times [body] as [name]; attributes are added before the body runs.
  Future<T> measure<T>(
    String name,
    Future<T> Function() body, {
    Map<String, String> attributes = const {},
  }) async {
    final trace = startTrace(name);
    attributes.forEach(trace.putAttribute);
    try {
      return await body();
    } catch (_) {
      trace.putAttribute('outcome', 'failed');
      rethrow;
    } finally {
      await trace.stop();
    }
  }

  /// Raw HTTP metric; null when collection is off. Used by `PerfHttpInterceptor`.
  PerfHttpMetric? startHttpMetric(String method, Uri url) {
    if (!_enabled) {
      return null;
    }
    final verb = httpMethod(method);
    final target = httpMetricUrl(url);
    if (verb == null || target == null) {
      return null;
    }
    try {
      return PerfHttpMetric._(
        FirebasePerformance.instance.newHttpMetric(target, verb),
      );
    } catch (error) {
      debugPrint('Performance http metric skipped: $error');
      return null;
    }
  }
}

/// One running custom trace. Safe to [stop] more than once.
class PerfTrace {
  PerfTrace._(Trace trace) : _trace = trace {
    _started = _begin(trace);
  }

  PerfTrace.disabled() : _trace = null {
    _started = Future<void>.value();
  }

  static const _maxAttributes = 5;

  final Trace? _trace;
  late final Future<void> _started;
  final _pending = <String, String>{};
  int _attributes = 0;
  bool _running = false;
  bool _stopped = false;

  Future<void> _begin(Trace trace) async {
    try {
      await trace.start();
    } catch (error) {
      debugPrint('Performance trace start failed: $error');
    }
    if (_stopped) {
      return;
    }
    _running = true;
    // Attributes set before the platform trace started would be dropped.
    _pending.forEach((name, value) {
      try {
        trace.putAttribute(name, value);
      } catch (_) {}
    });
    _pending.clear();
  }

  /// Ignored when the trace is disabled, stopped, or out of attribute slots.
  void putAttribute(String name, String value) {
    final trace = _trace;
    if (trace == null || _stopped || !_fits(name, value)) {
      return;
    }
    if (_attributes >= _maxAttributes) {
      return;
    }
    _attributes++;
    if (!_running) {
      _pending[name] = value;
      return;
    }
    try {
      trace.putAttribute(name, value);
    } catch (_) {}
  }

  Future<void> stop() async {
    final trace = _trace;
    if (trace == null || _stopped) {
      return;
    }
    _stopped = true;
    await _started;
    try {
      await trace.stop();
    } catch (error) {
      debugPrint('Performance trace stop failed: $error');
    }
  }
}

/// One HTTP metric. [finish] is idempotent and waits for the platform start.
class PerfHttpMetric {
  PerfHttpMetric._(this._metric) {
    _started = _begin();
  }

  final HttpMetric _metric;
  late final Future<void> _started;
  final _attributes = <String, String>{};
  int? _statusCode;
  String? _contentType;
  int? _payloadSize;
  bool _stopped = false;

  Future<void> _begin() async {
    try {
      await _metric.start();
    } catch (error) {
      debugPrint('Performance http metric start failed: $error');
    }
  }

  void respond({int? statusCode, String? contentType, int? payloadSize}) {
    if (_stopped) {
      return;
    }
    _statusCode = statusCode ?? _statusCode;
    if (contentType != null && contentType.length <= 100) {
      _contentType = contentType;
    }
    if (payloadSize != null && payloadSize >= 0) {
      _payloadSize = payloadSize;
    }
  }

  void putAttribute(String name, String value) {
    if (_stopped ||
        _attributes.length >= _maxAttributes ||
        !_fits(name, value)) {
      return;
    }
    _attributes[name] = value;
  }

  Future<void> finish() async {
    if (_stopped) {
      return;
    }
    _stopped = true;
    await _started;
    try {
      if (_statusCode != null) {
        _metric.httpResponseCode = _statusCode;
      }
      if (_contentType != null) {
        _metric.responseContentType = _contentType;
      }
      if (_payloadSize != null) {
        _metric.responsePayloadSize = _payloadSize;
      }
      _attributes.forEach(_metric.putAttribute);
      await _metric.stop();
    } catch (error) {
      debugPrint('Performance http metric finish failed: $error');
    }
  }

  static const _maxAttributes = 5;
}

/// Firebase trace names allow letters, digits, `_` and `-`, must not start with
/// `_` or a digit, and the console keeps the first 32 characters. Returns null
/// when nothing usable is left.
@visibleForTesting
String? traceName(String raw) {
  var cleaned = raw.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  if (cleaned.isEmpty) {
    return null;
  }
  if (!RegExp(r'^[A-Za-z]').hasMatch(cleaned)) {
    cleaned = 't_$cleaned';
  }
  return cleaned.length > 32 ? cleaned.substring(0, 32) : cleaned;
}

/// Metric URL: scheme + host + redacted path, no query and no fragment, so
/// search text, tokens and per-instance ids never reach the report.
@visibleForTesting
String? httpMetricUrl(Uri url) {
  if (url.scheme != 'http' && url.scheme != 'https') {
    return null;
  }
  if (url.host.isEmpty) {
    return null;
  }
  final path = redactPath(url.path);
  final formatted =
      '${url.scheme}://${url.host}${url.hasPort ? ':${url.port}' : ''}$path';
  return formatted.length <= 200 ? formatted : null;
}

@visibleForTesting
HttpMethod? httpMethod(String method) => switch (method.toUpperCase()) {
  'GET' => HttpMethod.Get,
  'POST' => HttpMethod.Post,
  'PUT' => HttpMethod.Put,
  'PATCH' => HttpMethod.Patch,
  'DELETE' => HttpMethod.Delete,
  'HEAD' => HttpMethod.Head,
  'OPTIONS' => HttpMethod.Options,
  _ => null,
};

/// Firebase drops attributes outside these limits without saying so.
bool _fits(String name, String value) =>
    name.isNotEmpty &&
    name.length <= 40 &&
    value.isNotEmpty &&
    value.length <= 100;
