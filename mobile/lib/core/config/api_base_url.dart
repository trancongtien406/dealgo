import 'package:flutter/foundation.dart' show kReleaseMode;

/// Production API on the VPS (Socket.IO uses the same host over wss).
const prodApiBaseUrl = 'https://api-dealgo.trancongtien.com';

/// Local Nest listens on 3001 (Admin Web takes 3000).
const devApiBaseUrl = 'http://localhost:3001';

/// Release builds default to [prodApiBaseUrl]; debug/profile to [devApiBaseUrl].
/// Override with `--dart-define=API_BASE_URL=...` (Android emulator:
/// `http://10.0.2.2:3001`, staging, etc.).
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: kReleaseMode ? prodApiBaseUrl : devApiBaseUrl,
);

/// Chat and all API traffic must use TLS outside local debug.
/// Release builds reject any http:// base URL; debug allows http only for
/// localhost, 127.0.0.1 and 10.0.2.2 (Android emulator).
void assertSecureApiBaseUrl(String url, {required bool isRelease}) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.scheme == 'https' || uri.scheme == 'wss') return;
  if (uri.scheme == 'http' || uri.scheme == 'ws') {
    const local = {'localhost', '127.0.0.1', '10.0.2.2'};
    if (!isRelease && local.contains(uri.host)) return;
    throw StateError(
      'Insecure API base URL scheme for this build: ${uri.scheme}',
    );
  }
}

String normalizeBaseUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.endsWith('/')) {
    return trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}

/// Media served by the API (e.g. `/v1/public/avatars/...`) comes back as a
/// relative path; absolute http(s) URLs pass through. Anything else is null.
String? resolveMediaUrl(String? url, {String base = apiBaseUrl}) {
  final value = url?.trim();
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('https://') || value.startsWith('http://')) return value;
  if (value.startsWith('/')) return '${normalizeBaseUrl(base)}$value';
  return null;
}
