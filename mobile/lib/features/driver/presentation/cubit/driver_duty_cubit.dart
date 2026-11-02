import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../live_location/domain/driver_location.dart';
import '../../../live_location/presentation/driver_location_reporter.dart';
import '../../../presence/domain/params/set_presence_params.dart';
import '../../../presence/domain/usecases/set_presence.dart';

class DriverDutyCubit extends Cubit<bool> {
  DriverDutyCubit({
    this._setPresence,
    this._accessToken,
    DriverLocationReporter? locationReporter,
    Future<bool?> Function()? fetchServerOnline,
    Stream<void>? reconnects,
    bool syncOnResume = false,
  }) : _reporter = locationReporter,
       _fetchServerOnline = fetchServerOnline,
       super(false) {
    // Server is the source of truth for duty: sync on open,
    // after a socket reconnect and when the app returns to the foreground.
    if (fetchServerOnline != null) {
      unawaited(syncFromServer());
      if (reconnects != null) {
        _reconnectSub = reconnects.listen((_) => unawaited(syncFromServer()));
      }
      if (syncOnResume) {
        _lifecycle = AppLifecycleListener(
          onResume: () => unawaited(syncFromServer()),
        );
      }
    }
  }

  final Future<bool?> Function()? _fetchServerOnline;
  StreamSubscription<void>? _reconnectSub;
  AppLifecycleListener? _lifecycle;
  bool _syncing = false;

  /// Adopts the server's `online` flag without writing presence back.
  Future<void> syncFromServer() async {
    final fetch = _fetchServerOnline;
    if (fetch == null || _syncing || isClosed) {
      return;
    }
    _syncing = true;
    try {
      final online = await fetch();
      if (online == null || isClosed || online == state) {
        return;
      }
      emit(online);
      if (online) {
        _reporter?.start();
      } else {
        _reporter?.stop();
      }
    } catch (_) {
      // Offline / 5xx: keep the current toggle; the next open/reconnect retries.
    } finally {
      _syncing = false;
    }
  }

  final SetPresence? _setPresence;
  final String? Function()? _accessToken;

  /// DEC-PROD-031: reports the driver's position while online.
  final DriverLocationReporter? _reporter;

  /// t82u: driver's last reported position while online (null offline/unknown).
  DriverLocationFix? get lastFix => state ? _reporter?.lastFix : null;

  Future<void> connect() async {
    if (state) {
      return;
    }
    emit(true);
    await _postPresence(online: true);
    _reporter?.start();
  }

  Future<void> disconnect() async {
    if (!state) {
      return;
    }
    emit(false);
    _reporter?.stop();
    await _postPresence(online: false);
  }

  @override
  Future<void> close() {
    _reporter?.stop();
    unawaited(_reconnectSub?.cancel());
    _lifecycle?.dispose();
    return super.close();
  }

  Future<void> _postPresence({required bool online}) async {
    final setPresence = _setPresence;
    final token = _accessToken?.call()?.trim() ?? '';
    if (setPresence == null || token.isEmpty) {
      return;
    }
    try {
      await setPresence(SetPresenceParams(accessToken: token, online: online));
    } catch (_) {
      // Soft-fail: local duty toggle remains authoritative for UI.
    }
  }
}

/// An in-progress job (opened from the feed, a deep link, a push or the
/// relaunch resume) keeps the driver online and the location reporter running,
/// otherwise the customer's map freezes on the last fix.
void ensureDriverOnDuty(BuildContext context) {
  DriverDutyCubit? duty;
  try {
    duty = context.read<DriverDutyCubit>();
  } on ProviderNotFoundException {
    return;
  }
  if (!duty.state) {
    unawaited(duty.connect());
  }
}
