import 'package:flutter/foundation.dart';

import '../../features/identity/domain/entities/app_role.dart';
import 'push_route_resolver.dart';

/// The explicit in-app `path` a push carries (e.g. a nearby ride
/// request → `/driver/jobs`). Absolute in-app paths only; never a URL.
String? notificationTapPath(Map<String, Object?> data) {
  final path = data['path'];
  if (path is! String) {
    return null;
  }
  final trimmed = path.trim();
  if (!trimmed.startsWith('/') || trimmed.startsWith('//')) {
    return null;
  }
  return trimmed;
}

/// Bridges push / in-app inbox taps to go_router locations.
///
/// A tap that arrives before the session is ready (cold start via
/// `getInitialMessage`, or while signed out) is kept and opened once
/// [flushPending] sees a signed-in user with a finished profile. Taps older
/// than [pendingTtl] are dropped so a stale push never hijacks a later login.
class NotificationRouter {
  NotificationRouter({
    this.onNavigate,
    this.readyRoles,
    this.pendingTtl = const Duration(minutes: 10),
    this.claimWindow = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  void Function(String location)? onNavigate;

  /// True when the router has a page for a location (bound by the app
  /// router); a push or link naming an unknown page never shows not-found.
  bool Function(String location)? routeExists;

  /// Payload key marking a parked app / universal link (not a push).
  static const linkKey = 'dealgoLink';

  /// Roles of a ready session, or null while restoring / signed out / in setup.
  List<AppRole>? Function()? readyRoles;

  final Duration pendingTtl;

  /// How long an opened push / inbox tap keeps relaunch resumers from
  /// navigating over it (see [claimsNavigation]).
  final Duration claimWindow;
  final DateTime Function() _clock;
  Map<String, Object?>? _pending;
  DateTime? _pendingAt;
  DateTime? _openedAt;

  /// True while a tap is waiting to open or was opened within [claimWindow]:
  /// the user picked a destination, so relaunch resumers (driver job / customer
  /// trip) must not navigate over it.
  bool get claimsNavigation {
    if (_pending != null) {
      return true;
    }
    final at = _openedAt;
    return at != null && _clock().difference(at) < claimWindow;
  }

  @visibleForTesting
  bool get hasPending => _pending != null;

  /// Marks a navigation the user picked outside a push (e.g. an app link)
  /// so relaunch resumers do not navigate over it.
  void claim() {
    _openedAt = _clock();
  }

  void bindNavigator(void Function(String location) navigate) {
    onNavigate = navigate;
  }

  void bindReadiness(List<AppRole>? Function() roles) {
    readyRoles = roles;
  }

  void bindRoutes(bool Function(String location) exists) {
    routeExists = exists;
  }

  /// Page a push / inbox tap or a parked link opens for [roles].
  String? resolve(Map<String, Object?> data, List<AppRole> roles) {
    final link = data[linkKey];
    if (link == true) {
      final path = notificationTapPath(data);
      return path == null
          ? null
          : resolveLinkLocation(path, roles, routeExists: routeExists);
    }
    final location = resolvePushLocation(data, roles);
    final exists = routeExists;
    if (location == null || exists == null || exists(location)) {
      return location;
    }
    // A stale server path (page renamed / removed): the shell's inbox.
    return _inboxOf(resolveLinkLocation(location, roles, routeExists: exists));
  }

  String _inboxOf(String home) {
    final role = AppRole.values.where(
      (r) => home == r.homePath || home.startsWith('${r.homePath}/'),
    );
    if (role.isEmpty) {
      return home;
    }
    final inbox = '${role.first.homePath}/account/notifications';
    return routeExists?.call(inbox) ?? true ? inbox : home;
  }

  /// FCM tap (foreground banner, background, or cold start).
  void handleTap(Map<String, Object?> data) {
    final roles = readyRoles?.call();
    if (roles == null || onNavigate == null) {
      _pending = Map<String, Object?>.of(data);
      _pendingAt = _clock();
      return;
    }
    _pending = null;
    openPath(resolve(data, roles));
  }

  /// Call when auth / profile state changes.
  void flushPending() {
    final data = _pending;
    final at = _pendingAt;
    if (data == null) {
      return;
    }
    if (at != null && _clock().difference(at) > pendingTtl) {
      _pending = null;
      return;
    }
    final roles = readyRoles?.call();
    if (roles == null || onNavigate == null) {
      return;
    }
    _pending = null;
    openPath(resolve(data, roles));
  }

  /// Inbox / FCM payload may carry a path like `/customer/ride/tracking/...`.
  void openPath(String? path) {
    final location = path?.trim() ?? '';
    if (location.isEmpty || !location.startsWith('/')) {
      return;
    }
    final navigate = onNavigate;
    if (navigate == null) {
      if (kDebugMode) {
        debugPrint('NotificationRouter: no navigator bound for $location');
      }
      return;
    }
    _openedAt = _clock();
    navigate(location);
  }
}
