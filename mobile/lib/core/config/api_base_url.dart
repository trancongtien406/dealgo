import 'package:flutter/foundation.dart' show kReleaseMode;

/// Production API on the VPS (Socket.IO uses the same host over wss).
const prodApiBaseUrl = 'https://api-dealgo.laptrinhapp.com';

/// Local Nest listens on 3001 (Admin Web takes 3000).
const devApiBaseUrl = 'http://localhost:3001';

/// Flutter flavor from `--flavor` or the Xcode `dev` / `prod` scheme.
const _flavor = String.fromEnvironment('FLUTTER_APP_FLAVOR');

/// Release builds and the `prod` flavor default to [prodApiBaseUrl]; other
/// debug/profile builds to [devApiBaseUrl]. Override with
/// `--dart-define=API_BASE_URL=...` (Android emulator: `http://10.0.2.2:3001`).
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: kReleaseMode || _flavor == 'prod'
      ? prodApiBaseUrl
      : devApiBaseUrl,
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
/// Public photo families the API re-encodes into width variants (`?w=`).
const _variantImagePrefixes = <String>[
  '/v1/public/avatars/',
  '/v1/public/store-logos/',
  '/v1/public/store-covers/',
  '/v1/public/menu-items/',
  '/v1/public/ride-vehicle-classes/',
  '/v1/public/home-banners/images/',
  '/v1/public/food-categories/images/',
];

/// Mirrors the server's generated widths, so every widget of a size bucket
/// shares one cache entry instead of downloading the same variant twice.
const _variantWidths = <int>[128, 240, 480, 1080];

int _variantWidth(int width) {
  for (final candidate in _variantWidths) {
    if (candidate >= width) return candidate;
  }
  return _variantWidths.last;
}

/// Asks the API for the smallest pre-resized copy that still covers [width]
/// physical pixels, so a thumbnail does not transfer the full upload.
String withImageWidth(String url, int? width) {
  if (width == null || width <= 0) return url;
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  if (!_variantImagePrefixes.any((prefix) => uri.path.startsWith(prefix))) {
    return url;
  }
  return uri
      .replace(
        queryParameters: {
          ...uri.queryParameters,
          'w': '${_variantWidth(width)}',
        },
      )
      .toString();
}

String? resolveMediaUrl(String? url, {String base = apiBaseUrl}) {
  final value = url?.trim();
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('https://') || value.startsWith('http://')) return value;
  if (value.startsWith('/')) return '${normalizeBaseUrl(base)}$value';
  return null;
}
