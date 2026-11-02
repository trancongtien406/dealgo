import 'dart:async';

import '../../../identity/domain/entities/app_role.dart';
import '../../data/datasources/customer_active_trip_client.dart';

/// Customer relaunch resume (DEC-PROD-057), once per signed-in customer per app
/// run: asks the API for a live ride / open food order and reopens its screen. Failed lookups retry
/// with exponential backoff up to [maxAttempts].
class CustomerTripResumer {
  CustomerTripResumer({
    required this._source,
    required this._navigate,
    required this._currentLocation,
    this.baseDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(seconds: 30),
    this.maxAttempts = 5,
    this._userNavigationClaimed,
    this._cachedRoute,
  });

  final CustomerActiveTripSource _source;

  /// Screen of the trip saved on the device, opened when the first lookup
  /// fails (no network) so the customer still sees it and can call.
  final Future<String?> Function()? _cachedRoute;
  final void Function(String route) _navigate;
  final String Function() _currentLocation;
  final Duration baseDelay;
  final Duration maxDelay;
  final int maxAttempts;

  /// True while a push / inbox tap owns navigation; never reopen over it.
  final bool Function()? _userNavigationClaimed;

  String? _handledUser;
  String? _pendingUser;
  Timer? _retry;
  int _generation = 0;

  bool get retryScheduled => _retry?.isActive ?? false;

  /// Never reopen inside the driver / merchant shells or over a trip screen
  /// that is already open (deep link, notification tap).
  static bool canReopenFrom(String location) {
    return !location.startsWith('/driver') &&
        !location.startsWith('/merchant') &&
        !location.startsWith('/customer/ride/') &&
        !location.startsWith('/customer/food/orders/');
  }

  Future<void> onSignedIn({
    required String userId,
    required List<AppRole> roles,
    required bool profileDone,
  }) async {
    if (!profileDone ||
        !roles.contains(AppRole.customer) ||
        _handledUser == userId ||
        _pendingUser == userId) {
      return;
    }
    reset();
    _pendingUser = userId;
    await _attempt(userId, _generation, 0);
  }

  Future<void> _attempt(String userId, int generation, int attempt) async {
    CustomerActiveTrip? trip;
    try {
      trip = await _source.fetch();
    } catch (_) {
      if (generation != _generation) {
        return;
      }
      if (attempt == 0) {
        await _openCached(generation);
        if (generation != _generation) {
          return;
        }
      }
      if (attempt + 1 >= maxAttempts) {
        _pendingUser = null;
        return;
      }
      var delay = baseDelay * (1 << attempt);
      if (delay > maxDelay) {
        delay = maxDelay;
      }
      _retry = Timer(delay, () => _attempt(userId, generation, attempt + 1));
      return;
    }
    if (generation != _generation) {
      return;
    }
    _pendingUser = null;
    _handledUser = userId;
    if (trip == null ||
        !canReopenFrom(_currentLocation()) ||
        (_userNavigationClaimed?.call() ?? false)) {
      return;
    }
    _navigate(trip.route);
  }

  Future<void> _openCached(int generation) async {
    final String? route;
    try {
      route = await _cachedRoute?.call();
    } catch (_) {
      return;
    }
    if (route == null ||
        generation != _generation ||
        !canReopenFrom(_currentLocation()) ||
        (_userNavigationClaimed?.call() ?? false)) {
      return;
    }
    _navigate(route);
  }

  /// Sign-out / account switch: forget the user and cancel pending retries.
  void reset() {
    _generation++;
    _retry?.cancel();
    _retry = null;
    _handledUser = null;
    _pendingUser = null;
  }
}
