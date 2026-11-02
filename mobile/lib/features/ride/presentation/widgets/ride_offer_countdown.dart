import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/design_system/tokens/dealgo_tokens.dart';

/// Remaining share (1 → 0) and whole seconds left of an offer.
typedef RideOfferCountdownBuilder = Widget Function(
  BuildContext context,
  double progress,
  int seconds,
);

/// t71u/t81u: a driver's offer lives [ttl] (server default 20s). The card stays
/// fully visible; [builder] gets the remaining share so only the Accept button
/// drains ([RideOfferAcceptButton]). The card disappears at `expiresAt`.
/// The server stays authoritative (late accept -> 409 RIDE_OFFER_EXPIRED).
class RideOfferCountdown extends StatefulWidget {
  const RideOfferCountdown({
    required this.expiresAt,
    required this.builder,
    this.ttl = const Duration(seconds: 20),
    this.now,
    this.onExpired,
    super.key,
  });

  final String expiresAt;
  final RideOfferCountdownBuilder builder;
  final Duration ttl;
  final DateTime Function()? now;
  final VoidCallback? onExpired;

  @override
  State<RideOfferCountdown> createState() => _RideOfferCountdownState();
}

class _RideOfferCountdownState extends State<RideOfferCountdown> {
  Timer? _timer;
  bool _notified = false;

  DateTime _now() => (widget.now ?? DateTime.now)();

  Duration get _remaining {
    final at = DateTime.tryParse(widget.expiresAt);
    if (at == null) return widget.ttl;
    final r = at.difference(_now());
    return r.isNegative ? Duration.zero : r;
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() {});
      if (_remaining == Duration.zero) {
        _timer?.cancel();
        if (!_notified) {
          _notified = true;
          widget.onExpired?.call();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remaining;
    if (remaining == Duration.zero) {
      return const SizedBox.shrink(key: Key('ride-offer-expired'));
    }
    final total = widget.ttl.inMilliseconds <= 0
        ? 1
        : widget.ttl.inMilliseconds;
    final p = (remaining.inMilliseconds / total).clamp(0.0, 1.0);
    final secs = (remaining.inMilliseconds / 1000).ceil();
    return widget.builder(context, p, secs);
  }
}

/// t81u: the Accept button carries the offer's countdown — the fill drains
/// left-to-right inside the button and the seconds sit next to the label
/// (inDrive-style). Turns red in the last 5 seconds.
class RideOfferAcceptButton extends StatelessWidget {
  const RideOfferAcceptButton({
    required this.label,
    required this.progress,
    required this.seconds,
    required this.onPressed,
    this.enabled = true,
    this.busy = false,
    this.height = 44,
    super.key,
  });

  final String label;
  final double progress;
  final int seconds;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool busy;
  final double height;

  @override
  Widget build(BuildContext context) {
    final urgent = seconds <= 5;
    final active = enabled && onPressed != null && !busy;
    final fill = urgent ? DealGoColors.danger : DealGoColors.primary;
    final textStyle = Theme.of(context).textTheme.labelLarge
        ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: SizedBox(
        height: height,
        child: Material(
          color: fill.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(DealGoRadius.button),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: active ? onPressed : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    key: const Key('ride-offer-countdown-bar'),
                    widthFactor: progress.clamp(0.0, 1.0),
                    heightFactor: 1,
                    child: ColoredBox(color: fill),
                  ),
                ),
                Center(
                  child: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      // Narrow inline cards: shrink rather than overflow.
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(label, maxLines: 1, style: textStyle),
                              const SizedBox(width: 6),
                              Text(
                                '${seconds}s',
                                key: const Key('ride-offer-countdown-text'),
                                style: textStyle?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
