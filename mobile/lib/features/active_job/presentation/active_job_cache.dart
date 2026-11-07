import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../driver_card/domain/driver_card.dart';
import '../data/active_job_snapshot_store.dart';
import '../domain/active_job_snapshot.dart';

/// The signed-in customer's latest ride / food order as last confirmed by the
/// server, so it can still be shown (and its driver called) without network.
///
/// Only one job is kept; a newer running job replaces it. Owned per user:
/// another account never sees it, and sign-out wipes it.
class ActiveJobCache {
  ActiveJobCache({required this._store, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ActiveJobSnapshotStore _store;
  final DateTime Function() _clock;

  String? _userId;
  StoredActiveJob? _current;
  Future<void>? _loaded;
  Future<void> _writes = Future.value();

  void bindUser(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    _current = null;
    _loaded = null;
  }

  /// The bound user's snapshot (of job [id] when given), or null when none,
  /// expired, or the job ended more than [ActiveJobSnapshot.endedGrace] ago.
  Future<ActiveJobSnapshot?> lookup({String? id}) async {
    final user = _userId;
    if (user == null) return null;
    await _ensureLoaded();
    final stored = _current;
    if (stored == null || stored.userId != user || user != _userId) {
      return null;
    }
    if (!stored.snapshot.usableAt(_clock())) {
      await clear();
      return null;
    }
    if (id != null && stored.snapshot.id != id) return null;
    return stored.snapshot;
  }

  /// Saves a fresh server copy of a job. A finished job only updates its own
  /// snapshot: reopening an old receipt never replaces the running one. The
  /// saved driver is kept only while [assignedDriverId] still matches it.
  Future<void> recordJob(
    ActiveJobSnapshot job, {
    required bool terminal,
    required String? assignedDriverId,
  }) async {
    final user = _userId;
    if (user == null) return;
    await _ensureLoaded();
    if (user != _userId) return;
    final previous = _current;
    final sameJob =
        previous != null &&
        previous.userId == user &&
        previous.snapshot.kind == job.kind &&
        previous.snapshot.id == job.id;
    if (terminal && !sameJob) return;
    final now = _clock();
    var next = job.savedAtTime(now);
    if (sameJob) {
      final driver = previous.snapshot.driver;
      if (job.driver == null &&
          driver != null &&
          driver.driverId == assignedDriverId) {
        next = next.withDriver(driver);
      }
      final endedAt = previous.snapshot.endedAt;
      if (endedAt != null) next = next.endedAtTime(endedAt);
    }
    if (terminal) next = next.endedAtTime(now);
    return _persist(StoredActiveJob(userId: user, snapshot: next));
  }

  Future<void> recordDriver({
    required ActiveJobKind kind,
    required String jobId,
    required DriverCard card,
  }) async {
    final user = _userId;
    if (user == null) return;
    await _ensureLoaded();
    final current = _current;
    if (current == null ||
        current.userId != user ||
        current.snapshot.kind != kind ||
        current.snapshot.id != jobId) {
      return;
    }
    return _persist(
      StoredActiveJob(
        userId: user,
        snapshot: current.snapshot.withDriver(card),
      ),
    );
  }

  Future<void> clear() {
    _current = null;
    return _writes = _writes.then((_) => _store.clear());
  }

  /// Clears a stale snapshot only when it still points at [id].
  ///
  /// A late 404 from an old tracking screen must not erase a newer job that
  /// has already replaced it in the cache.
  Future<void> clearIfMatches(String id) async {
    final user = _userId;
    if (user == null) return;
    await _ensureLoaded();
    final current = _current;
    if (user != _userId ||
        current == null ||
        current.userId != user ||
        current.snapshot.id != id) {
      return;
    }
    await clear();
  }

  Future<void> _ensureLoaded() => _loaded ??= _store.read().then((value) {
    _current ??= value;
  });

  Future<void> _persist(StoredActiveJob value) {
    _current = value;
    return _writes = _writes.then((_) => _store.write(value));
  }
}

/// The app's cache, or null in isolated widget tests mounted without it.
ActiveJobCache? maybeActiveJobCache(BuildContext context) {
  try {
    return Provider.of<ActiveJobCache>(context, listen: false);
  } on ProviderNotFoundException {
    return null;
  }
}
