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
