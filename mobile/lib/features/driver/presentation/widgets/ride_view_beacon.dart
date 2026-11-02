import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../ride/domain/negotiation/ride_negotiation_client.dart';
import '../../../ride/presentation/widgets/ride_negotiation_ui.dart';
import 'driver_widgets.dart';

/// Tells the server this driver currently has [rideId] on screen.
class RideViewBeacon extends StatefulWidget {
  const RideViewBeacon({required this.rideId, super.key});

  final String rideId;

  /// Off in widget tests so a heartbeat timer cannot block [WidgetTester.pumpAndSettle].
  static bool enabled = true;

  @override
  State<RideViewBeacon> createState() => _RideViewBeaconState();
}

class _RideViewSessions {
  static final holds = <String, int>{};

  static bool acquire(String rideId) {
    final next = (holds[rideId] ?? 0) + 1;
    holds[rideId] = next;
    return next == 1;
  }

  static bool release(String rideId) {
    final next = (holds[rideId] ?? 1) - 1;
    if (next <= 0) {
      holds.remove(rideId);
      return true;
    }
    holds[rideId] = next;
    return false;
  }
}

class _RideViewBeaconState extends State<RideViewBeacon> {
  Timer? _pulse;
  RideNegotiationClient? _client;
  String? _token;
  var _holding = false;

  @override
  void initState() {
    super.initState();
    if (!RideViewBeacon.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void didUpdateWidget(covariant RideViewBeacon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rideId == widget.rideId) return;
    _stop(oldWidget.rideId);
    _start();
  }

  @override
  void dispose() {
    _stop(widget.rideId);
    super.dispose();
  }

  void _start() {
    if (!mounted || !RideViewBeacon.enabled || _holding) return;
    final client = maybeRideNegotiation(context);
    final token = _readToken();
    if (client == null || token == null) return;
    _client = client;
    _token = token;
    _holding = true;
    _RideViewSessions.acquire(widget.rideId);
    unawaited(_beat());
    _pulse = Timer.periodic(const Duration(seconds: 8), (_) {
      unawaited(_beat());
    });
  }

  void _stop(String rideId) {
    _pulse?.cancel();
    _pulse = null;
    if (!_holding) return;
    _holding = false;
    final last = _RideViewSessions.release(rideId);
    final client = _client;
    final token = _token;
    _client = null;
    _token = null;
    if (!last || client == null || token == null) return;
    unawaited(
      client
          .leaveViewing(accessToken: token, rideId: rideId)
          .catchError((Object _) {}),
    );
  }

  String? _readToken() {
    try {
      return driverAccessToken(context);
    } catch (_) {
      return null;
    }
  }

  Future<void> _beat() async {
    final client = _client;
    final token = _token;
    if (client == null || token == null || !mounted) return;
    try {
      await client.noteViewing(accessToken: token, rideId: widget.rideId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
