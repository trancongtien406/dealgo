import 'package:flutter/material.dart';

import '../../motion/dealgo_motion.dart';
import '../tokens/dealgo_tokens.dart';
import 'dealgo_haptics.dart';
import 'dealgo_nav_insets.dart';

class DealGoTabDestination {
  const DealGoTabDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badgeCount = 0,
  });

  final String label;

  /// Outline icon for an inactive tab.
  final IconData icon;

  /// Icon shown inside the raised circle while the tab is active.
  final IconData selectedIcon;

  /// Unread count; 0 hides the badge, above 99 shows "99+".
  final int badgeCount;
}

/// Role bottom navigation: a floating pill inset from the screen edges.
///
/// The active tab's icon rises into a brand circle above the pill, and the
/// pill has a smooth concave notch around that circle. Circle and notch slide
/// to the selected tab ([DealGoMotion.medium], [DealGoMotion.standard]; no
/// motion when the platform asks for reduced motion). Every tab keeps its
/// short label inside the pill.
///
/// Use with `Scaffold(extendBody: true)` and clear the body by
/// [DealGoNavBarMetrics.contentClearance] (see `RoleShell`).
class DealGoTabBar extends StatelessWidget {
  const DealGoTabBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final List<DealGoTabDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Pill height (see [kDealGoNavBarHeight]).
  static const double barHeight = kDealGoNavBarHeight;

  /// Diameter of the raised active circle.
  static const double circleSize = 48;

  /// Gap between the circle and the notch edge.
  static const double notchGap = 5;

  /// How far the circle centre sits below the pill top.
  static const double circleDip = circleSize / 2 - kDealGoNavOverhang;

  @override
  Widget build(BuildContext context) {
    final nav = dealGoNavBarMetricsOf(context);
    final count = destinations.length;
    final selected = selectedIndex.clamp(0, count - 1);
    final duration = DealGoMotion.durationFor(context, DealGoMotion.medium);

    return SizedBox(
      key: const Key('dealgo-tab-bar'),
      height: nav.totalHeight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          kDealGoNavSideMargin,
          0,
          kDealGoNavSideMargin,
          nav.bottomGap,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / count;
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(end: selected.toDouble()),
              duration: duration,
              curve: DealGoMotion.standard,
              builder: (context, position, _) {
                final cx = (position + 0.5) * itemWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: nav.overhang,
                      height: nav.barHeight,
                      child: CustomPaint(
                        key: const Key('dealgo-tab-bar-pill'),
                        painter: DealGoNotchedBarPainter(
                          notchCenterX: cx,
                          notchCenterY: circleDip,
                          notchRadius: circleSize / 2 + notchGap,
                        ),
                        child: Row(
                          children: [
                            for (var i = 0; i < count; i++)
                              Expanded(
                                child: _TabItem(
                                  destination: destinations[i],
                                  selected: i == selected,
                                  // 1 = icon fully visible, 0 = under the circle.
                                  iconVisibility: (position - i).abs().clamp(
                                    0.0,
                                    1.0,
                                  ),
                                  onTap: () {
                                    if (i != selected) {
                                      DealGoHaptics.selection();
                                    }
                                    onDestinationSelected(i);
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: cx - circleSize / 2,
                      top: nav.overhang + circleDip - circleSize / 2,
                      width: circleSize,
                      height: circleSize,
                      child: _ActiveCircle(
                        destination:
                            destinations[position.round().clamp(0, count - 1)],
                        onTap: () => onDestinationSelected(selected),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Paints the pill with a smooth concave notch centred on [notchCenterX].
class DealGoNotchedBarPainter extends CustomPainter {
  const DealGoNotchedBarPainter({
    required this.notchCenterX,
    required this.notchCenterY,
    required this.notchRadius,
    this.radius = DealGoRadius.card,
  });

  final double notchCenterX;

  /// Notch centre, measured from the pill top (positive = inside the pill).
  final double notchCenterY;
  final double notchRadius;
  final double radius;

  Path pathFor(Size size) {
    final host = Offset.zero & size;
    final guest = Rect.fromCircle(
      center: Offset(notchCenterX, notchCenterY),
      radius: notchRadius,
    );
    final notched = const CircularNotchedRectangle().getOuterPath(host, guest);
    final rounded = Path()
      ..addRRect(RRect.fromRectAndRadius(host, Radius.circular(radius)));
    return Path.combine(PathOperation.intersect, rounded, notched);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = pathFor(size);
    canvas.drawPath(
      path.shift(const Offset(0, 6)),
      Paint()
        ..color = const Color(0x244C1D95)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawPath(path, Paint()..color = DealGoColors.card);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = DealGoColors.border,
    );
  }

  /// Taps are handled by the tab row painted on top.
  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(DealGoNotchedBarPainter old) =>
      old.notchCenterX != notchCenterX ||
      old.notchCenterY != notchCenterY ||
      old.notchRadius != notchRadius ||
      old.radius != radius;
}

class _ActiveCircle extends StatelessWidget {
  const _ActiveCircle({required this.destination, required this.onTap});

  final DealGoTabDestination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: GestureDetector(
        key: const Key('dealgo-tab-bar-active'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [DealGoColors.primaryLight, DealGoColors.primary],
            ),
            // Tighter than DealGoShadows.button so no glow pools in the
            // notch gap under the circle.
            boxShadow: [
              BoxShadow(
                color: Color(0x336D28D9),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: _Badged(
              count: destination.badgeCount,
              child: Icon(
                destination.selectedIcon,
                size: 22,
                color: DealGoColors.card,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.destination,
    required this.selected,
    required this.iconVisibility,
    required this.onTap,
  });

  final DealGoTabDestination destination;
  final bool selected;
  final double iconVisibility;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = selected ? DealGoColors.primary : DealGoColors.textSecondary;
    final badge = destination.badgeCount;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      value: badge > 0 ? (badge > 99 ? '99+' : '$badge') : null,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 9, 4, 7),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Opacity(
                  opacity: iconVisibility,
                  child: _Badged(
                    count: badge,
                    child: Icon(destination.icon, size: 22, color: color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  destination.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: (textTheme.labelSmall ?? const TextStyle()).copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 11,
                    height: 1.1,
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

class _Badged extends StatelessWidget {
  const _Badged({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      backgroundColor: DealGoColors.danger,
      textColor: DealGoColors.card,
      child: child,
    );
  }
}
