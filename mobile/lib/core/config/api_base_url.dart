/// Local Nest listens on 3011 (website/BFF often takes 3001). Override with
/// `--dart-define=API_BASE_URL=...` when the API port differs.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3011',
);

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
