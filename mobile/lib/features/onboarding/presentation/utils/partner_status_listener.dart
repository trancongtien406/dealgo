import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/realtime/snapshot_realtime.dart';

/// Keeps a partner status page in sync without polling: the backend pushes
/// `partnerStatus` on the user's private socket room when an admin approves or
/// rejects. REST is read only on open (the page's own load), on socket
/// reconnect, on app resume, and when that push arrives.
mixin PartnerStatusListener<T extends StatefulWidget> on State<T>
    implements WidgetsBindingObserver {
  StreamSubscription<PartnerStatusHint>? _partnerStatusSub;
  StreamSubscription<void>? _partnerReconnectSub;

  /// `DRIVER` or `MERCHANT`; pushes for other roles are ignored.
  String get partnerStatusRole;

  /// Whether the application is still waiting for a decision.
  bool get pendingStatusActive;

  /// Reloads the application from the server.
  Future<void> refreshPendingStatus();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SnapshotRealtime? realtime;
    try {
      realtime = context.read<SnapshotRealtime>();
    } catch (_) {
      realtime = null;
    }
    _partnerStatusSub = realtime?.partnerStatuses.listen((hint) {
      if (mounted && hint.role == partnerStatusRole) {
        unawaited(refreshPendingStatus());
      }
    });
    _partnerReconnectSub = realtime?.reconnects.listen((_) {
      if (mounted && pendingStatusActive) {
        unawaited(refreshPendingStatus());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && pendingStatusActive) {
      unawaited(refreshPendingStatus());
    }
  }

  @override
  void dispose() {
    unawaited(_partnerStatusSub?.cancel());
    unawaited(_partnerReconnectSub?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
