import 'package:flutter/material.dart';

import 'dealgo_motion.dart';

/// One-shot entrance for list rows: fade + short rise, staggered by [index].
///
/// The delay is capped so long lists never wait on off-screen rows, and the
/// row renders in place with no animation under reduced motion.
class DealGoStaggerIn extends StatefulWidget {
  const DealGoStaggerIn({required this.index, required this.child, super.key});

  final int index;
  final Widget child;

  static const Duration step = Duration(milliseconds: 40);
  static const int maxStaggered = 6;

  @override
  State<DealGoStaggerIn> createState() => _DealGoStaggerInState();
}

class _DealGoStaggerInState extends State<DealGoStaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: DealGoMotion.medium,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: DealGoMotion.standard,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (DealGoMotion.prefersReducedMotion(context)) {
      _controller.value = 1;
      return;
    }
    final slot = widget.index.clamp(0, DealGoStaggerIn.maxStaggered);
    Future<void>.delayed(DealGoStaggerIn.step * slot, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// Expanding rings behind [child] — the "still looking" signal while a
/// request waits on someone else (finding a driver, active tracking step).
/// Static when [DealGoMotion.ambientLoops] is off (reduced motion, tests).
class DealGoPulse extends StatefulWidget {
  const DealGoPulse({
    required this.child,
    required this.color,
    this.diameter = 56,
    this.active = true,
    super.key,
  });

  final Widget child;
  final Color color;
  final double diameter;
  final bool active;

  @override
  State<DealGoPulse> createState() => _DealGoPulseState();
}

class _DealGoPulseState extends State<DealGoPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  void _sync() {
    final run = widget.active && DealGoMotion.ambientLoops(context);
    if (run && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!run && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant DealGoPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (_controller.isAnimating)
          for (final offset in const [0.0, 0.5])
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final t = (_controller.value + offset) % 1;
                  return Transform.scale(
                    scale: 1 + 0.7 * t,
                    child: Container(
                      width: widget.diameter,
                      height: widget.diameter,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.color.withValues(alpha: 0.28 * (1 - t)),
                      ),
                    ),
                  );
                },
              ),
            ),
        widget.child,
      ],
    );
  }
}

/// Cross-fades a status headline when its text changes (order or trip moving
/// to the next stage). Instant under reduced motion.
class DealGoStatusSwitcher extends StatelessWidget {
  const DealGoStatusSwitcher({required this.child, super.key});

  /// Must carry a key that changes with the status.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: DealGoMotion.durationFor(context, DealGoMotion.medium),
      switchInCurve: DealGoMotion.standard,
      switchOutCurve: DealGoMotion.standard,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topLeft,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Shared-element image between a list row and its detail page. Disabled
/// under reduced motion so the photo simply appears with the page.
class DealGoHero extends StatelessWidget {
  const DealGoHero({required this.tag, required this.child, super.key});

  final Object tag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return HeroMode(
      enabled: !DealGoMotion.prefersReducedMotion(context),
      child: Hero(
        tag: tag,
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

/// Press-down scale for cards that already own an InkWell: listens to the
/// pointer without taking the gesture, so ripple, semantics and scrolling stay
/// with the card. No scale under reduced motion.
class DealGoPressScale extends StatefulWidget {
  const DealGoPressScale({required this.child, super.key});

  final Widget child;

  @override
  State<DealGoPressScale> createState() => _DealGoPressScaleState();
}

class _DealGoPressScaleState extends State<DealGoPressScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = DealGoMotion.prefersReducedMotion(context);
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed && !reduced ? 0.98 : 1,
        duration: DealGoMotion.fast,
        curve: DealGoMotion.standard,
        child: widget.child,
      ),
    );
  }
}

/// Slides [child] up from the bottom edge and fades it in when it appears,
/// and back down when it becomes null (floating cart bar). The reserved
/// height animates with it. Instant under reduced motion.
class DealGoSlideReveal extends StatelessWidget {
  const DealGoSlideReveal({this.child, super.key});

  /// null hides the slot. Give it a key so a content swap stays in place.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final duration = DealGoMotion.durationFor(context, DealGoMotion.medium);
    return AnimatedSize(
      duration: duration,
      curve: DealGoMotion.standard,
      alignment: Alignment.bottomCenter,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: DealGoMotion.standard,
        switchOutCurve: DealGoMotion.standard,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.bottomCenter,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.6),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child:
            child ??
            const SizedBox(key: ValueKey('hidden'), width: double.infinity),
      ),
    );
  }
}
