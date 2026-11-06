import 'package:flutter/material.dart';

import '../../motion/dealgo_motion.dart';
import '../tokens/dealgo_tokens.dart';

/// Diagonal shimmer sweep for loading placeholders. Static under reduced motion.
class DealGoShimmer extends StatefulWidget {
  const DealGoShimmer({
    required this.child,
    this.animateInTests = true,
    super.key,
  });

  final Widget child;
  final bool animateInTests;

  @override
  State<DealGoShimmer> createState() => _DealGoShimmerState();
}

class _DealGoShimmerState extends State<DealGoShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1350),
  );

  bool _shouldAnimate(BuildContext context) {
    if (DealGoMotion.prefersReducedMotion(context)) return false;
    if (!widget.animateInTests &&
        WidgetsBinding.instance.runtimeType.toString().contains(
          'TestWidgetsFlutterBinding',
        )) {
      return false;
    }
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_shouldAnimate(context)) {
      _controller.stop();
      _controller.value = 0.5;
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
    final base = DealGoColors.skeletonBase;
    final highlight = DealGoColors.skeletonHighlight;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final t = _controller.value;
          final dx = -1.6 + 3.2 * t;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment(dx - 0.85, -0.35),
                end: Alignment(dx + 0.85, 0.35),
                colors: [base, highlight, base],
                stops: const [0.15, 0.5, 0.85],
              ).createShader(bounds);
            },
            child: child,
          );
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

/// Hero banner / carousel shimmer skeleton.
class DealGoBannerSkeleton extends StatelessWidget {
  const DealGoBannerSkeleton({
    this.height = 156,
    this.padding = const EdgeInsets.symmetric(
      horizontal: DealGoDimensions.pageGutter,
    ),
    super.key,
  });

  final double height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: DealGoShimmer(
        child: Container(
          height: height,
          padding: const EdgeInsets.all(DealGoSpacing.s16),
          decoration: BoxDecoration(
            color: DealGoColors.card,
            borderRadius: BorderRadius.circular(DealGoRadius.card),
            border: Border.all(color: DealGoColors.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DealGoSkeletonBox(width: 76, height: 18, radius: DealGoRadius.pill),
              Spacer(),
              FractionallySizedBox(
                widthFactor: 0.65,
                child: DealGoSkeletonBox(height: 18),
              ),
              SizedBox(height: DealGoSpacing.s8),
              FractionallySizedBox(
                widthFactor: 0.42,
                child: DealGoSkeletonBox(height: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Featured store / dish card skeleton (16:9 photo header + title + meta + chips).
class DealGoStoreCardSkeleton extends StatelessWidget {
  const DealGoStoreCardSkeleton({
    this.padding = const EdgeInsets.symmetric(
      horizontal: DealGoDimensions.pageGutter,
    ),
    super.key,
  });

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: DealGoShimmer(
        child: Container(
          decoration: BoxDecoration(
            color: DealGoColors.card,
            borderRadius: BorderRadius.circular(DealGoRadius.card),
            border: Border.all(color: DealGoColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DealGoSkeletonBox(height: 124, radius: 0),
              Padding(
                padding: EdgeInsets.all(DealGoSpacing.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(
                      widthFactor: 0.62,
                      child: DealGoSkeletonBox(height: 16),
                    ),
                    SizedBox(height: DealGoSpacing.s8),
                    FractionallySizedBox(
                      widthFactor: 0.44,
                      child: DealGoSkeletonBox(height: 12),
                    ),
                    SizedBox(height: DealGoSpacing.s12),
                    Row(
                      children: [
                        DealGoSkeletonBox(
                          width: 68,
                          height: 22,
                          radius: DealGoRadius.small,
                        ),
                        SizedBox(width: DealGoSpacing.s8),
                        DealGoSkeletonBox(
                          width: 84,
                          height: 22,
                          radius: DealGoRadius.small,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 2-column grid of card skeletons (for category / product grids).
class DealGoGridSkeleton extends StatelessWidget {
  const DealGoGridSkeleton({
    this.itemCount = 4,
    this.crossAxisCount = 2,
    this.padding = const EdgeInsets.all(DealGoDimensions.pageGutter),
    super.key,
  });

  final int itemCount;
  final int crossAxisCount;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DealGoShimmer(
      child: GridView.builder(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: itemCount,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: DealGoSpacing.s12,
          mainAxisSpacing: DealGoSpacing.s12,
          childAspectRatio: 0.85,
        ),
        itemBuilder: (context, index) => Container(
          padding: const EdgeInsets.all(DealGoSpacing.s12),
          decoration: BoxDecoration(
            color: DealGoColors.card,
            borderRadius: BorderRadius.circular(DealGoRadius.card),
            border: Border.all(color: DealGoColors.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DealGoSkeletonBox(
                  width: double.infinity,
                  radius: DealGoRadius.input,
                ),
              ),
              SizedBox(height: DealGoSpacing.s12),
              FractionallySizedBox(
                widthFactor: 0.78,
                child: DealGoSkeletonBox(height: 14),
              ),
              SizedBox(height: DealGoSpacing.s6),
              FractionallySizedBox(
                widthFactor: 0.48,
                child: DealGoSkeletonBox(height: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
