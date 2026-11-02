import '../../features/identity/domain/entities/app_role.dart';
import 'notification_router.dart';

/// Where a tapped push / inbox row should land for the
/// signed-in user. Mirrors `backend/src/modules/communication/notification/push-path.ts`.
///
/// Order: the server `path` when this user's roles may open it → the same
/// account page in a shell the user has → a page derived from
/// `aggregateType` / `aggregateId` / `status` / `role` → the inbox (fallback,
/// never a dead page). Returns null when the payload names nothing at all.
String? resolvePushLocation(Map<String, Object?> data, List<AppRole> roles) {
  final allowed = roles.isEmpty ? const [AppRole.customer] : roles;
  final hinted = _roleOf(data['role']);
  final role = hinted != null && allowed.contains(hinted)
      ? hinted
      : _guessRole(data, allowed);

  final serverPath = notificationTapPath(data);
  if (serverPath != null) {
    if (shellAllows(serverPath, allowed)) {
      return serverPath;
    }
    final rehomed = _rehomeAccountPath(serverPath, role);
    if (rehomed != null) {
      return rehomed;
    }
  }

  final derived = derivePushPath(data, role);
  if (derived != null && shellAllows(derived, allowed)) {
    return _withChatOpen(derived, data);
  }
  if (serverPath == null && _text(data['aggregateType']) == null) {
    return null;
  }
  return '${role.homePath}/account/notifications';
}

/// Where an app / universal link to [location] opens for [roles].
///
/// A page the user's shells may open and the router knows is kept as is.
/// Otherwise the link never lands on a dead or foreign page: an unknown page
/// in one of the user's shells opens that shell's home, an account page of
/// another shell moves into the user's own, and anything else opens the
/// user's entry page (the customer home, see [entryPathFor]).
String resolveLinkLocation(
  String location,
  List<AppRole> roles, {
  bool Function(String location)? routeExists,
}) {
  final allowed = roles.isEmpty ? const [AppRole.customer] : roles;
  bool known(String l) => routeExists?.call(l) ?? true;
  if (shellAllows(location, allowed) && known(location)) {
    return location;
  }
  final path = Uri.parse(location).path;
  for (final role in allowed) {
    if (path == role.homePath || path.startsWith('${role.homePath}/')) {
      return role.homePath;
    }
  }
  final rehomed = _rehomeAccountPath(path, allowed.first);
  if (rehomed != null && known(rehomed)) {
    return rehomed;
  }
  return entryPathFor(allowed);
}

/// Page for one aggregate as seen by [role] (no permission check).
String? derivePushPath(Map<String, Object?> data, AppRole role) {
  final type = _text(data['aggregateType']);
  final id = _text(data['aggregateId']);
  final status = _text(data['status']) ?? '';
  final event = _text(data['eventType']) ?? '';
  final gone = const {'CANCELLED', 'EXPIRED', 'FAILED'}.contains(status);
  final chat = _opensChat(event);
  if (type == 'PartnerApplication') {
    return _text(data['partnerRole']) == 'MERCHANT'
        ? '/merchant/kyb/status'
        : '/driver/kyc/status';
  }
  if (type == 'NotificationCampaign') {
    return '${role.homePath}/account/notifications';
  }
  if (id == null) {
    return null;
  }
  final seg = Uri.encodeComponent(id);
  switch (type) {
    case 'Ride':
      switch (role) {
        case AppRole.customer:
          return status == 'NEGOTIATING'
              ? '/customer/ride/offers/$seg'
              : '/customer/ride/tracking/$seg';
        case AppRole.driver:
          // NEGOTIATING reaches a driver only when the ride went to someone
          // else (ops reassign / start timeout): the trip page is gone.
          if (event.contains('request') ||
              (gone && !chat) ||
              (status == 'NEGOTIATING' && !chat)) {
            return '/driver/jobs';
          }
          return '/driver/rides/$seg/active';
        case AppRole.merchant:
          return null;
      }
    case 'FoodOrder':
      switch (role) {
        case AppRole.customer:
          // Same as the server path: a gone order opens Shop, not the
          // full-screen detail (that page has no bottom nav).
          if (!chat && (gone || status == 'REJECTED')) {
            return '/customer/shop';
          }
          return '/customer/food/orders/$seg';
        case AppRole.driver:
          // A nearby READY order ("request") is not the driver's yet: open the job list.
          return event.contains('request') || (gone && !chat)
              ? '/driver/jobs'
              : '/driver/food/$seg';
        case AppRole.merchant:
          return gone ? '/merchant/orders' : '/merchant/orders/$seg';
      }
    case 'SupportTicket':
      return '${role.homePath}/account/help/tickets/$seg';
  }
  return null;
}

/// Job pages with a chat sheet (mirrors `CHAT_PAGES` in push-path.ts).
final _chatPages = [
  RegExp(r'^/customer/ride/tracking/[^/?]+$'),
  RegExp(r'^/driver/rides/[^/?]+/active$'),
  RegExp(r'^/customer/food/orders/[^/?]+$'),
  RegExp(r'^/driver/food/[^/?]+$'),
];

/// Chat messages and missed calls land in the job's conversation (the missed
/// call leaves a note there).
bool _opensChat(String event) =>
    event.startsWith('Chat.') || event == 'Call.missed';

/// A chat push without a server path still opens the conversation (`?chat=1`).
String _withChatOpen(String path, Map<String, Object?> data) {
  final event = _text(data['eventType']) ?? '';
  if (!_opensChat(event) || !_chatPages.any((p) => p.hasMatch(path))) {
    return path;
  }
  return '$path?chat=1';
}

AppRole? _roleOf(Object? raw) => raw is String ? AppRole.fromGrant(raw) : null;

String? _text(Object? raw) {
  if (raw is! String) {
    return null;
  }
  final value = raw.trim();
  return value.isEmpty ? null : value;
}

/// Without a role hint: a merchant-only or driver-only account opens its own
/// shell; otherwise the customer view (the party that placed the job).
AppRole _guessRole(Map<String, Object?> data, List<AppRole> allowed) {
  final event = _text(data['eventType']) ?? '';
  if (event.contains('request') && allowed.contains(AppRole.driver)) {
    return AppRole.driver;
  }
  if (allowed.contains(AppRole.customer)) {
    return AppRole.customer;
  }
  return allowed.first;
}

/// `/customer/account/help/tickets/1` → `/driver/account/help/tickets/1` for a
/// driver-only account (support and inbox pages exist in every shell).
String? _rehomeAccountPath(String path, AppRole role) {
  final match = RegExp(r'^/(customer|driver|merchant)(/account(?:/.*)?)$')
      .firstMatch(path);
  if (match == null) {
    return null;
  }
  return '${role.homePath}${match.group(2)}';
}

/// Page an inbox row opens inside the shell at [shellPath]
/// (`/driver/account`, …), or null when the row names nothing to open.
String? inboxTargetFor({
  required String shellPath,
  String? aggregateType,
  String? aggregateId,
  String? status,
  String? path,
}) {
  final role = AppRole.values.firstWhere(
    (r) => shellPath == r.homePath || shellPath.startsWith('${r.homePath}/'),
    orElse: () => AppRole.customer,
  );
  final target = resolvePushLocation(
    {
      'aggregateType': ?aggregateType,
      'aggregateId': ?aggregateId,
      'status': ?status,
      'path': ?path,
      'role': role.grantName,
    },
    [role],
  );
  if (target == null || target == '${role.homePath}/account/notifications') {
    return null;
  }
  return target;
}
