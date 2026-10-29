import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/media/alert_audio.dart';
import '../../../../core/notifications/notification_router.dart';
import '../../../../core/push/new_job_alert.dart';
import '../../../../core/realtime/snapshot_realtime.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/entities/ride_money.dart';
import '../cubit/driver_duty_cubit.dart';
import '../cubit/driver_feed_cubit.dart';
import '../utils/driver_routes.dart';
import 'driver_widgets.dart';

/// Loops the new-job sound and vibration while an incoming-job card is up.
abstract interface class IncomingJobRinger {
  Future<void> start({required bool customSound});
  Future<void> stop();
}

class AudioIncomingJobRinger implements IncomingJobRinger {
  AudioPlayer? _player;
  Timer? _buzz;

  @override
  Future<void> start({required bool customSound}) async {
    await stop();
    _buzz = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      unawaited(HapticFeedback.vibrate());
    });
    unawaited(HapticFeedback.vibrate());
    try {
      final player = AudioPlayer(playerId: 'dealgo-incoming-job');
      _player = player;
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(
        AlertAudio.source(
          customSound ? NewJobAlertKind.ride.asset : AlertAudio.notifyAsset,
        ),
        ctx: AlertAudio.ring,
      );
    } catch (_) {
      // Vibration keeps going; a missing audio session never hides the card.
    }
  }

  @override
  Future<void> stop() async {
    _buzz?.cancel();
    _buzz = null;
    final player = _player;
    _player = null;
    if (player != null) {
      try {
        await player.stop();
        await player.dispose();
      } catch (_) {}
    }
  }
}

/// Grab/Be/inDrive-style incoming job: while a matching open ride exists that
/// the driver has not handled, a full-screen card with countdown stays up and
/// rings + vibrates until "Xem & báo giá", "Bỏ qua", expiry, or the ride leaves
/// the feed (cancelled / taken / expired — the feed is refreshed on socket
/// hints, push taps, resume and every [pollEvery] while the card is up).
/// The list comes from the same `GET /v1/rides/open` as "Việc nhận", so the
/// alert criteria are the feed criteria.
class IncomingJobAlertHost extends StatefulWidget {
  const IncomingJobAlertHost({
    super.key,
    required this.child,
    this.ringer,
    this.clock,
    this.pollEvery = const Duration(seconds: 10),
    this.inCall,
  });

  /// Off in widget tests that drive the job list directly (flutter_test_config);
  /// the alert's own tests turn it back on.
  static bool enabled = true;

  final Widget child;
  final IncomingJobRinger? ringer;
  final DateTime Function()? clock;
  final Duration pollEvery;
  final bool Function()? inCall;

  @override
  State<IncomingJobAlertHost> createState() => _IncomingJobAlertHostState();
}

class _IncomingJobAlertHostState extends State<IncomingJobAlertHost> {
  late final IncomingJobRinger _ringer =
      widget.ringer ?? AudioIncomingJobRinger();
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () => _refresh(),
  );
  final _handled = <String>{};
  final _subs = <StreamSubscription<Object?>>[];
  OpenRide? _current;
  Timer? _tick;
  Timer? _poll;
  Timer? _debounce;
  bool _ringing = false;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _lifecycle;
    SnapshotRealtime? realtime;
    try {
      realtime = context.read<SnapshotRealtime>();
    } catch (_) {
      realtime = null;
    }
    if (realtime != null) {
      _subs.add(realtime.jobRequests.listen((_) => _refreshSoon()));
      _subs.add(realtime.reconnects.listen((_) => _refreshSoon()));
    }
    _subs.add(driverJobPushTaps.listen((_) => _refreshSoon()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _evaluate(context.read<DriverFeedCubit>().state);
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _tick?.cancel();
    _poll?.cancel();
    _debounce?.cancel();
    _lifecycle.dispose();
    unawaited(_ringer.stop());
    super.dispose();
  }

  void _refreshSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _refresh);
  }

  void _refresh() {
    if (!mounted) return;
    bool online;
    String? token;
    try {
      online = context.read<DriverDutyCubit>().state;
      token = driverAccessToken(context);
    } catch (_) {
      return; // Not under the signed-in driver scope (tests / sign-out).
    }
    if (!online) {
      _dismiss();
      return;
    }
    unawaited(
      context.read<DriverFeedCubit>().sync(
        online: online,
        accessToken: token,
        quiet: true,
      ),
    );
  }

  bool _expired(OpenRide ride) {
    final at = DateTime.tryParse(ride.expiresAt);
    return at != null && !at.isAfter(_now());
  }

  void _evaluate(DriverFeedState feed) {
    if (!IncomingJobAlertHost.enabled) return;
    if (feed is! DriverFeedReady) {
      if (feed is DriverFeedIdle || feed is DriverFeedIneligible) _dismiss();
      return;
    }
    final current = _current;
    if (current != null) {
      final still = feed.rides.any((r) => r.id == current.id);
      if (!still || _expired(current)) {
        _handled.add(current.id);
        _dismiss();
      } else {
        return;
      }
    }
    final next = feed.rides.where(
      (r) => !_handled.contains(r.id) && !_expired(r),
    );
    if (next.isNotEmpty) _show(next.first);
  }

  void _show(OpenRide ride) {
    setState(() => _current = ride);
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final c = _current;
      if (c == null) return;
      if (_expired(c)) {
        _handled.add(c.id);
        _dismiss();
        _evaluate(context.read<DriverFeedCubit>().state);
      } else {
        setState(() {});
      }
    });
    _poll?.cancel();
    _poll = Timer.periodic(widget.pollEvery, (_) => _refresh());
    final inCall = (widget.inCall ?? NewJobAlert.instance.inCall)();
    if (!inCall && !_ringing) {
      _ringing = true;
      unawaited(_ringer.start(customSound: NewJobAlert.instance.customSound));
    }
  }

  void _dismiss() {
    _tick?.cancel();
    _poll?.cancel();
    if (_ringing) {
      _ringing = false;
      unawaited(_ringer.stop());
    }
    if (_current != null && mounted) setState(() => _current = null);
  }

  void _skip() {
    final c = _current;
    if (c == null) return;
    _handled.add(c.id);
    _dismiss();
    _evaluate(context.read<DriverFeedCubit>().state);
  }

  void _open() {
    final c = _current;
    if (c == null) return;
    _handled.add(c.id);
    _dismiss();
    context.push(DriverRoutes.ride(c.id), extra: c);
  }

  @override
  Widget build(BuildContext context) {
    final ride = _current;
    return BlocListener<DriverFeedCubit, DriverFeedState>(
      listener: (context, feed) => _evaluate(feed),
      child: Stack(
        children: [
          widget.child,
          if (ride != null)
            Positioned.fill(
              child: _IncomingJobCard(
                ride: ride,
                secondsLeft: _secondsLeft(ride),
                onOpen: _open,
                onSkip: _skip,
              ),
            ),
        ],
      ),
    );
  }

  int? _secondsLeft(OpenRide ride) {
    final at = DateTime.tryParse(ride.expiresAt);
    if (at == null) return null;
    final s = at.difference(_now()).inSeconds;
    return s < 0 ? 0 : s;
  }
}

class _IncomingJobCard extends StatelessWidget {
  const _IncomingJobCard({
    required this.ride,
    required this.secondsLeft,
    required this.onOpen,
    required this.onSkip,
  });

  final OpenRide ride;
  final int? secondsLeft;
  final VoidCallback onOpen;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final left = secondsLeft;
    final mm = left == null
        ? ''
        : '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
    return Material(
      key: const Key('incoming-job-alert'),
      color: Colors.black54,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(DealGoSpacing.s16),
            padding: const EdgeInsets.all(DealGoSpacing.s20),
            decoration: BoxDecoration(
              color: DealGoColors.card,
              borderRadius: BorderRadius.circular(DealGoRadius.card),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.incomingJobTitle,
                        style: text.titleMedium,
                      ),
                    ),
                    if (mm.isNotEmpty)
                      Text(
                        mm,
                        key: const Key('incoming-job-countdown'),
                        style: text.titleMedium?.copyWith(
                          color: DealGoColors.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: DealGoSpacing.s8),
                Text(
                  formatRideVnd(ride.offeredFareVnd),
                  style: text.headlineSmall,
                ),
                const SizedBox(height: DealGoSpacing.s12),
                Text(
                  ride.pickup.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: DealGoSpacing.s4),
                Text(
                  '→ ${ride.dropoff.label}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
                const SizedBox(height: DealGoSpacing.s16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('incoming-job-skip'),
                        onPressed: onSkip,
                        child: Text(l10n.incomingJobSkip),
                      ),
                    ),
                    const SizedBox(width: DealGoSpacing.s12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        key: const Key('incoming-job-open'),
                        onPressed: onOpen,
                        child: Text(l10n.incomingJobOpen),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
