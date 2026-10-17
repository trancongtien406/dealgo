/// Parses DealGo app / universal links into go_router locations.
/// Registration with the OS and go_router hook is deferred (shell only).
class DeepLinkParser {
  const DeepLinkParser();

  static const appScheme = 'dealgo';
  static const httpsHosts = {'app.dealgo.vn', 'dealgo.app'};

  /// Returns a go_router location (path + query) or null when unrecognized.
  String? parse(Uri uri) {
    if (uri.scheme == appScheme) {
      final path = uri.path.isEmpty ? '/${uri.host}' : '/${uri.host}${uri.path}';
      final normalized = path.replaceAll(RegExp(r'/+'), '/');
      if (normalized == '/') {
        return null;
      }
      return uri.hasQuery ? '$normalized?${uri.query}' : normalized;
    }

    if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        httpsHosts.contains(uri.host)) {
      final path = uri.path.isEmpty ? '/' : uri.path;
      if (path == '/') {
        return null;
      }
      return uri.hasQuery ? '$path?${uri.query}' : path;
    }

    return null;
  }
}
