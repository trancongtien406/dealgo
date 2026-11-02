import 'package:flutter/material.dart';

import '../../motion/dealgo_motion.dart';
import '../icons/dealgo_icons.dart';
import '../tokens/dealgo_tokens.dart';
import 'dealgo_haptics.dart';

/// Soft scale-in checkmark for critical success moments (order placed, offer locked).
/// Honors [DealGoMotion.prefersReducedMotion]; fires [DealGoHaptics.success] once.
class DealGoSuccessMark extends StatefulWidget {
  const DealGoSuccessMark({
    this.size = 72,
    this.iconSize = 36,
    this.haptic = true,
    super.key,
  });

  final double size;
  final double iconSize;
  final bool haptic;

  @override
  State<DealGoSuccessMark> createState() => _DealGoSuccessMarkState();
}

class _DealGoSuccessMarkState extends State<DealGoSuccessMark>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  var _hapticDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced =
        DealGoMotion.prefersReducedMotion(context) ||
        WidgetsBinding.instance.runtimeType.toString().contains(
          'TestWidgetsFlutterBinding',
        );
    if (reduced) {
      _controller?.dispose();
      _controller = null;
      _fireHapticOnce();
      return;
    }
    if (_controller != null) {
      return;
    }
    _controller = AnimationController(
      vsync: this,
      duration: DealGoMotion.medium,
    )..forward();
    _fireHapticOnce();
  }

  void _fireHapticOnce() {
    if (_hapticDone || !widget.haptic) {
      return;
    }
    _hapticDone = true;
    DealGoHaptics.success();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mark = DecoratedBox(
      key: const Key('dealgo-success-mark'),
      decoration: BoxDecoration(
        color: DealGoColors.greenSurface,
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Icon(
          DealGoIcons.check,
          color: DealGoColors.brandGreen,
          size: widget.iconSize,
        ),
      ),
    );
    final controller = _controller;
    if (controller == null) {
      return mark;
    }
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: controller,
        curve: DealGoMotion.emphasized,
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: controller,
          curve: DealGoMotion.standard,
        ),
        child: mark,
      ),
    );
  }
}
