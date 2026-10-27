import '../config/app_env.dart';

/// Parses DealGo app / universal links into go_router locations:
/// `dealgo://customer/home` and `https://<appLinkHost>/app/customer/home`.
class DeepLinkParser {
  const DeepLinkParser({this.host = appLinkHost});

  static const appScheme = 'dealgo';

  final String host;

  bool _isAppHost(String value) => value == host || value == 'www.$host';

  /// Returns a go_router location (path + query) or null when unrecognized.
  String? parse(Uri uri) {
    if (uri.scheme == appScheme) {
      final host = uri.host == 'app' ? '' : uri.host;
      final path = uri.path.isEmpty ? '/$host' : '/$host${uri.path}';
      final normalized = path.replaceAll(RegExp(r'/+'), '/');
      if (normalized == '/') {
        return null;
      }
      return uri.hasQuery ? '$normalized?${uri.query}' : normalized;
    }

    if (uri.scheme == 'https' && _isAppHost(uri.host)) {
      final path = uri.path;
      if (!path.startsWith('$appLinkPathPrefix/')) {
        return null;
      }
      final location = path.substring(appLinkPathPrefix.length);
      if (location == '/') {
        return null;
      }
      return uri.hasQuery ? '$location?${uri.query}' : location;
    }

    return null;
  }
}
