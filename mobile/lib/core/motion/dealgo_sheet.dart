import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../design_system/tokens/dealgo_tokens.dart';
import 'dealgo_motion.dart';

/// Distance (in logical pixels) a sheet must be pulled down to dismiss on release.
const double _kSheetDismissDistance = 72;

/// Downward fling velocity (in logical pixels/second) that dismisses a pulled sheet.
const double _kSheetDismissVelocity = 550;

const ShapeBorder _kDefaultSheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
);

/// Shared modal sheet entry — one place for radius, barrier, reduced-motion,
/// and TikTok-style pull-down-to-dismiss from both headers and scroll views.
Future<T?> showDealGoSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  Color? backgroundColor,
  bool useRootNavigator = false,
  bool useSafeArea = false,
  bool isDismissible = true,
  bool enableDrag = true,
  ShapeBorder? shape,
  Clip? clipBehavior,
}) {
  final reduce = DealGoMotion.prefersReducedMotion(context);
  final effectiveColor = backgroundColor ?? DealGoColors.card;
  final effectiveShape = shape ?? _kDefaultSheetShape;
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    // Keep the outer BottomSheet container transparent so translating
    // DealGoDismissibleSheet moves the actual visible sheet surface and
    // rounded top corners together without leaving a stationary background.
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: reduce ? 0.45 : 0.32),
    sheetAnimationStyle: reduce
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: DealGoMotion.medium,
            reverseDuration: DealGoMotion.fast,
            curve: DealGoMotion.standard,
          ),
    shape: effectiveShape,
    builder: (sheetContext) => DealGoDismissibleSheet(
      enabled: isDismissible && enableDrag,
      backgroundColor: effectiveColor,
      shape: effectiveShape,
      clipBehavior: clipBehavior,
      child: builder(sheetContext),
    ),
  );
}

/// Wraps modal bottom sheet content so pulling down when a nested scroll view
/// is at its top edge immediately drags the entire sheet surface (including its
/// background and rounded top corners) downward 1:1 with the finger.
class DealGoDismissibleSheet extends StatefulWidget {
  const DealGoDismissibleSheet({
    required this.child,
    this.enabled = true,
    this.backgroundColor,
    this.shape = _kDefaultSheetShape,
    this.clipBehavior,
    super.key,
  });

  final Widget child;
  final bool enabled;
  final Color? backgroundColor;
  final ShapeBorder shape;
  final Clip? clipBehavior;

  @override
  State<DealGoDismissibleSheet> createState() => _DealGoDismissibleSheetState();
}

class _DealGoDismissibleSheetState extends State<DealGoDismissibleSheet>
    with SingleTickerProviderStateMixin {
  late final _SheetDragController _drag = _SheetDragController(
    onChanged: _onDragChanged,
  );
  late final AnimationController _snapBack = AnimationController(
    vsync: this,
    duration: DealGoMotion.fast,
  )..addListener(_onSnapTick);

  double _snapStartOffset = 0;
  int? _activePointer;
  VelocityTracker? _velocityTracker;
  bool _dismissing = false;

  @override
  void dispose() {
    _snapBack.dispose();
    super.dispose();
  }

  void _onDragChanged() {
    if (mounted && !_dismissing) {
      setState(() {});
    }
  }

  void _onSnapTick() {
    if (!mounted || _dismissing) return;
    final t = Curves.easeOutCubic.transform(_snapBack.value);
    _drag.setSilently(_snapStartOffset * (1 - t));
    setState(() {});
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled || _dismissing) return;
    if (_snapBack.isAnimating) {
      _snapBack.stop();
    }
    _activePointer ??= event.pointer;
    if (_activePointer == event.pointer) {
      _velocityTracker = VelocityTracker.withKind(event.kind)
        ..addPosition(event.timeStamp, event.position);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    _velocityTracker?.addPosition(event.timeStamp, event.position);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    final tracker = _velocityTracker;
    tracker?.addPosition(event.timeStamp, event.position);
    final velocityY = tracker?.getVelocity().pixelsPerSecond.dy ?? 0;
    _activePointer = null;
    _velocityTracker = null;
    _finishDrag(velocityY: velocityY);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    _velocityTracker = null;
    _finishDrag(velocityY: 0);
  }

  void _finishDrag({required double velocityY}) {
    if (!mounted || _dismissing) return;
    final offset = _drag.dragOffset;
    if (offset <= 0) return;

    final shouldDismiss =
        offset >= _kSheetDismissDistance ||
        (offset > 12 && velocityY >= _kSheetDismissVelocity);
    if (shouldDismiss) {
      _dismissing = true;
      Navigator.of(context).maybePop();
      return;
    }

    _snapStartOffset = offset;
    _snapBack.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? DealGoColors.card;
    final isTransparent = bgColor.a == 0;
    final surface = isTransparent
        ? Material(
            type: MaterialType.transparency,
            child: widget.child,
          )
        : Material(
            color: bgColor,
            surfaceTintColor: Colors.transparent,
            shape: widget.shape,
            clipBehavior: widget.clipBehavior ?? Clip.antiAlias,
            child: widget.child,
          );

    if (!widget.enabled) {
      return surface;
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: ScrollConfiguration(
        behavior: _SheetScrollBehavior(controller: _drag),
        child: Transform.translate(
          offset: Offset(0, _drag.dragOffset),
          child: surface,
        ),
      ),
    );
  }
}

class _SheetDragController {
  _SheetDragController({required this.onChanged});

  final VoidCallback onChanged;
  double _dragOffset = 0;

  double get dragOffset => _dragOffset;

  void setSilently(double value) {
    _dragOffset = math.max(0, value);
  }

  void addDrag(double delta) {
    if (delta <= 0) return;
    _dragOffset += delta;
    onChanged();
  }

  /// Reduces [dragOffset] by up to [delta] and returns the absorbed amount.
  double reduceDrag(double delta) {
    if (delta <= 0 || _dragOffset <= 0) return 0;
    final absorbed = math.min(_dragOffset, delta);
    _dragOffset -= absorbed;
    onChanged();
    return absorbed;
  }
}

class _SheetScrollBehavior extends ScrollBehavior {
  const _SheetScrollBehavior({required this.controller});

  final _SheetDragController controller;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return _SheetScrollPhysics(
      controller: controller,
      parent: const ClampingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
    );
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _SheetScrollPhysics extends ClampingScrollPhysics {
  const _SheetScrollPhysics({required this.controller, super.parent});

  final _SheetDragController controller;

  @override
  _SheetScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _SheetScrollPhysics(
      controller: controller,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (position.axis != Axis.vertical) {
      return super.applyPhysicsToUserOffset(position, offset);
    }

    if (position.axisDirection == AxisDirection.down) {
      // Finger moving down (offset > 0): scroll to top first, then pull sheet down.
      if (offset > 0.0) {
        final availableScroll = math.max(
          0.0,
          position.pixels - position.minScrollExtent,
        );
        if (offset > availableScroll) {
          controller.addDrag(offset - availableScroll);
          return availableScroll;
        }
      } else if (offset < 0.0 && controller.dragOffset > 0.0) {
        // Finger moving back up while the sheet is pulled down: return sheet to 0 first.
        final absorbed = controller.reduceDrag(-offset);
        final remainingUp = (-offset) - absorbed;
        return -remainingUp;
      }
    } else if (position.axisDirection == AxisDirection.up) {
      // Reversed list (e.g. chat): visual top is at maxScrollExtent, and
      // finger moving down produces offset < 0.
      if (offset < 0.0) {
        final downDelta = -offset;
        final availableScroll = math.max(
          0.0,
          position.maxScrollExtent - position.pixels,
        );
        if (downDelta > availableScroll) {
          controller.addDrag(downDelta - availableScroll);
          return -availableScroll;
        }
      } else if (offset > 0.0 && controller.dragOffset > 0.0) {
        final absorbed = controller.reduceDrag(offset);
        return offset - absorbed;
      }
    }

    return super.applyPhysicsToUserOffset(position, offset);
  }
}
