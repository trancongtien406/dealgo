import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Redacts credentials and secrets before writing HTTP traffic to logs.
@visibleForTesting
String redactForLog(String input) {
  var out = input;
  out = out.replaceAllMapped(
    RegExp(r'(Authorization\s*[:=]\s*)Bearer\s+\S+', caseSensitive: false),
    (match) => '${match[1]}Bearer ***',
  );
  out = out.replaceAllMapped(
    RegExp(
      r'''(['"]Authorization['"]\s*:\s*['"])Bearer\s+[^'"]+(['"])''',
      caseSensitive: false,
    ),
    (match) => '${match[1]}Bearer ***${match[2]}',
  );
  const keys = <String>[
    'accessToken',
    'refreshToken',
    'password',
    'newPassword',
    'otp',
    'code',
    'token',
    'idToken',
    'authorizationCode',
    'body', // chat message text
  ];
  for (final key in keys) {
    out = out.replaceAllMapped(
      RegExp(
        '''(['"]$key['"]\\s*:\\s*['"])([^'"]*)(['"])''',
        caseSensitive: false,
      ),
      (match) => '${match[1]}***${match[3]}',
    );
  }
  return out;
}

/// Debug-only Dio traffic logger. Never attach in release builds.
Interceptor? createDealGoLogInterceptor({bool? enabled}) {
  if (!(enabled ?? kDebugMode)) {
    return null;
  }
  return LogInterceptor(
    request: true,
    requestHeader: true,
    requestBody: true,
    responseHeader: false,
    responseBody: true,
    error: true,
    logPrint: (object) => debugPrint(redactForLog(object.toString())),
  );
}
