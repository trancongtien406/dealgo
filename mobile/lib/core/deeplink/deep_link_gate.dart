import '../../features/identity/domain/auth_redirect.dart';
import '../notifications/notification_router.dart';
import '../notifications/push_route_resolver.dart';
import 'deep_link_parser.dart';

/// Turns an external app / universal link (`dealgo://driver/rides/<id>?chat=1`)
/// that reaches go_router into an in-app location.
///
/// go_router only matches `uri.path`, so without this the `dealgo://` host
/// (`driver`, `customer`) is lost and the link lands on the not-found page.
/// When the session is not ready yet (cold start restore, signed out) the
/// link is parked in [NotificationRouter] and opened after sign-in, exactly
/// like a cold-start push tap.
class DeepLinkGate {
  DeepLinkGate({
    required this.notifications,
    this.parser = const DeepLinkParser(),
  });

  final NotificationRouter notifications;
  final DeepLinkParser parser;
  int _nonce = 0;

  /// True when the app router has a page for a location.
  bool Function(String location)? routeExists;

  /// Binds the route table (links and push taps share it).
  void bindRoutes(bool Function(String location) exists) {
    routeExists = exists;
    notifications.bindRoutes(exists);
  }

  /// True for a URI that came from outside the app (has a scheme).
  static bool isExternal(Uri uri) =>
      uri.scheme == DeepLinkParser.appScheme ||
      uri.scheme == 'https' ||
      uri.scheme == 'http';

  /// Location to redirect to, or null when [uri] is a normal in-app location.
  String? intercept(Uri uri) {
    if (!isExternal(uri)) {
      return null;
    }
    final parsed = parser.parse(uri);
    if (parsed == null) {
      // Unknown external link: never the debug/not-found page.
      return AuthRoutes.splash;
    }
    final target = _withNonce(
      canonicalDeepLinkLocation(parsed, routeExists: routeExists),
    );
    final roles = notifications.readyRoles?.call();
    if (roles == null) {
      // Opened after sign-in with the same rules (role guard, unknown page).
      notifications.handleTap({
        'path': target,
        NotificationRouter.linkKey: true,
      });
      return AuthRoutes.splash;
    }
    final location = resolveLinkLocation(
      target,
      roles,
      routeExists: routeExists,
    );
    notifications.claim();
    return location;
  }

  /// A repeated chat link must still reopen the chat on the same page, so
  /// each external chat link gets a distinct location.
  String _withNonce(String location) {
    final uri = Uri.parse(location);
    final chat = uri.queryParameters['chat'];
    if (chat == null || chat.isEmpty || chat == '0') {
      return location;
    }
    _nonce++;
    return uri
        .replace(queryParameters: {...uri.queryParameters, 'dl': '$_nonce'})
        .toString();
  }
}

final _driverRide = RegExp(r'^/driver/rides/([^/?]+)$');
final _customerRide = RegExp(r'^/customer/rides?/([^/?]+)$');

/// `/customer/ride/<page>` booking pages that are not a ride id.
const _customerRidePages = {
  'tracking',
  'matching',
  'route',
  'vehicle',
  'fare',
  'fare-detail',
};

/// Maps short public link shapes onto the trip pages:
/// - `/driver/rides/<id>?chat=1` → `/driver/rides/<id>/active?chat=1`
///   (chat only exists on an assigned trip);
/// - `/customer/ride/<id>`, `/customer/rides/<id>` → ride tracking.
/// `dealgo://app/<role>/...` and a trailing `/` are accepted too. With
/// [routeExists] a path the router already knows is never rewritten.
String canonicalDeepLinkLocation(
  String location, {
  bool Function(String location)? routeExists,
}) {
  var uri = Uri.parse(location);
  var path = uri.path;
  if (path.startsWith('/app/')) {
    path = path.substring(4);
  }
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  if (routeExists != null && !_driverRide.hasMatch(path) && routeExists(path)) {
    return Uri(path: path, query: uri.hasQuery ? uri.query : null).toString();
  }
  final chat = uri.queryParameters['chat'];
  final wantsChat = chat != null && chat.isNotEmpty && chat != '0';
  final driverRide = _driverRide.firstMatch(path);
  if (driverRide != null && wantsChat) {
    path = '/driver/rides/${driverRide.group(1)}/active';
  }
  final customerRide = _customerRide.firstMatch(path);
  if (customerRide != null &&
      !_customerRidePages.contains(customerRide.group(1))) {
    path = '/customer/ride/tracking/${customerRide.group(1)}';
  }
  uri = Uri(path: path, query: uri.hasQuery ? uri.query : null);
  return uri.toString();
}
