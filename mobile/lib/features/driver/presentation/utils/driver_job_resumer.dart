import 'dart:async';

import '../../../../core/realtime/snapshot_realtime.dart';
import '../../../identity/domain/entities/app_role.dart';
import '../../data/datasources/driver_active_job_client.dart';

/// Relaunch resume (once per signed-in driver per app run): asks the API for
/// the in-progress job, puts the driver back on duty (presence + location
/// reporter) and opens the job screen. A failed lookup (network / 5xx) is
/// retried with exponential backoff for the rest of the session.
class DriverJobResumer {
  DriverJobResumer({
    required this._source,
    required this._ensureOnline,
    required this._navigate,
    this.baseDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(seconds: 60),
    this.maxAttempts = 8,
    this._currentLocation,
    this._jobHints,
    this._reconnects,
    this._userNavigationClaimed,
  });

  final DriverActiveJobSource _source;
  final void Function() _ensureOnline;
  final void Function(String route) _navigate;
  final Duration baseDelay;
  final Duration maxDelay;
  final int maxAttempts;
  final String Function()? _currentLocation;

  /// True while a push / inbox tap owns navigation (it just opened, or is
  /// waiting for sign-in). The resumer still puts the driver back on duty but
  /// does not open the job screen over the page the user tapped.
  final bool Function()? _userNavigationClaimed;

  bool get _yieldToUser => _userNavigationClaimed?.call() ?? false;

  bool _checking = false;

  /// Socket push: the server sends an ASSIGNED `snapshot` hint to
  /// the driver's private `user:` room. With hints wired there is no timer at
  /// all — REST runs only on sign-in/open, on a hint, and on reconnect.
  final Stream<SnapshotHint>? _jobHints;
  final Stream<void>? _reconnects;
  final _hintSubs = <StreamSubscription<Object?>>[];

  bool get usesPush => _jobHints != null;

  String? _handledUser;
  String? _pendingUser;
  Timer? _retry;
  int _generation = 0;

  bool get retryScheduled => _retry?.isActive ?? false;

  Future<void> onSignedIn({
    required String userId,
    required List<AppRole> roles,
    required bool profileDone,
  }) async {
    if (!profileDone ||
        !roles.contains(AppRole.driver) ||
        _handledUser == userId ||
        _pendingUser == userId) {
      return;
    }
    reset();
    _pendingUser = userId;
    await _attempt(userId, _generation, 0);
  }

  Future<void> _attempt(String userId, int generation, int attempt) async {
    DriverActiveJob? job;
    try {
      job = await _source.fetch();
    } catch (_) {
      if (generation != _generation) {
        return;
      }
      if (attempt + 1 >= maxAttempts) {
        _pendingUser = null;
        return;
      }
      final factor = 1 << attempt;
      var delay = baseDelay * factor;
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
    _startWatch(generation);
    if (job == null) {
      return;
    }
    _ensureOnline();
    if (_yieldToUser) {
      return;
    }
    _navigate(job.route);
  }

  void _startWatch(int generation) {
    if (_currentLocation == null) {
      return;
    }
    for (final sub in _hintSubs) {
      unawaited(sub.cancel());
    }
    _hintSubs.clear();
    final hints = _jobHints;
    if (hints != null) {
      _hintSubs.add(
        hints.listen((hint) {
          if (generation == _generation && hint.status == 'ASSIGNED') {
            unawaited(recheck());
          }
        }),
      );
      final reconnects = _reconnects;
      if (reconnects != null) {
        _hintSubs.add(
          reconnects.listen((_) {
            if (generation == _generation) {
              unawaited(recheck());
            }
          }),
        );
      }
    }
    // t50u: no watch timer. Without hints wired, a job assigned while the app
    // is open is picked up on foreground resume / sign-in only.
  }

  static bool _onJobScreen(String location) =>
      location.startsWith('/driver/rides/') ||
      location.startsWith('/driver/food/');

  /// Opens a newly ASSIGNED in-progress job when the driver is not already on a
  /// job screen. Called on an ASSIGNED hint, on reconnect and when the app returns to foreground.
  Future<void> recheck() async {
    final where = _currentLocation;
    if (where == null || _handledUser == null || _checking) {
      return;
    }
    if (_onJobScreen(where())) {
      return;
    }
    final generation = _generation;
    _checking = true;
    DriverActiveJob? job;
    try {
      job = await _source.fetch();
    } catch (_) {
      job = null;
    } finally {
      _checking = false;
    }
    if (job == null || generation != _generation) {
      return;
    }
    final location = where();
    if (_onJobScreen(location) || location == job.route) {
      return;
    }
    _ensureOnline();
    if (_yieldToUser) {
      return;
    }
    _navigate(job.route);
  }

  /// Sign-out / account switch: forget the user and cancel pending retries.
  void reset() {
    _generation++;
    for (final sub in _hintSubs) {
      unawaited(sub.cancel());
    }
    _hintSubs.clear();
    _retry?.cancel();
    _retry = null;
    _handledUser = null;
    _pendingUser = null;
  }
}
