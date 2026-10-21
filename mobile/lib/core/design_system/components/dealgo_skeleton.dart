import 'package:flutter/material.dart';

import '../../motion/dealgo_motion.dart';
import '../tokens/dealgo_tokens.dart';

/// Shimmer sweep for loading placeholders. Static under reduced motion.
class DealGoShimmer extends StatefulWidget {
  const DealGoShimmer({required this.child, super.key});

  final Widget child;

  @override
  State<DealGoShimmer> createState() => _DealGoShimmerState();
}

class _DealGoShimmerState extends State<DealGoShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (DealGoMotion.prefersReducedMotion(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final t = _controller.value;
          final opacity = 0.55 + 0.45 * (1 - (2 * t - 1).abs());
          return Opacity(opacity: opacity, child: child);
        },
      ),
    );
  }
}

/// A single placeholder block.
class DealGoSkeletonBox extends StatelessWidget {
  const DealGoSkeletonBox({
    this.width,
    this.height = 14,
    this.radius = DealGoRadius.small,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: DealGoColors.skeletonBase,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// List of card-shaped placeholders (avatar/thumb + two text lines).
class DealGoSkeletonList extends StatelessWidget {
  const DealGoSkeletonList({
    this.itemCount = 4,
    this.padding = const EdgeInsets.all(DealGoDimensions.pageGutter),
    this.thumbSize = 56,
    this.semanticLabel,
    super.key,
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;
  final double thumbSize;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      liveRegion: true,
      child: DealGoShimmer(
        child: ListView.separated(
          padding: padding,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: itemCount,
          separatorBuilder: (_, _) => const SizedBox(height: DealGoSpacing.s12),
          itemBuilder: (context, index) => Container(
            padding: const EdgeInsets.all(DealGoSpacing.s12),
            decoration: BoxDecoration(
              color: DealGoColors.card,
              borderRadius: BorderRadius.circular(DealGoRadius.card),
            ),
            child: Row(
              children: [
                DealGoSkeletonBox(
                  width: thumbSize,
                  height: thumbSize,
                  radius: DealGoRadius.input,
                ),
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(
                        widthFactor: index.isEven ? 0.7 : 0.55,
                        child: const DealGoSkeletonBox(height: 14),
                      ),
                      const SizedBox(height: DealGoSpacing.s8),
                      const FractionallySizedBox(
                        widthFactor: 0.4,
                        child: DealGoSkeletonBox(height: 12),
                      ),
                    ],
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
