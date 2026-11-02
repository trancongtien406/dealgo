import 'package:flutter/material.dart';

import '../../motion/dealgo_motion.dart';
import '../../motion/dealgo_motion_widgets.dart';
import '../icons/dealgo_icons.dart';
import '../tokens/dealgo_tokens.dart';

/// Grab/ShopeeFood-style tracking layout: the live map fills the screen and a
/// draggable bottom sheet carries ETA, timeline, people and money.
class TrackingScaffold extends StatelessWidget {
  const TrackingScaffold({
    required this.map,
    required this.sheet,
    required this.onBack,
    this.topTrailing,
    this.topCenter,
    this.footer,
    this.initialSize = 0.48,
    this.minSize = 0.3,
    super.key,
  });

  final Widget map;
  final List<Widget> sheet;
  final VoidCallback onBack;
  final Widget? topTrailing;
  final Widget? topCenter;
  final Widget? footer;
  final double initialSize;
  final double minSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: map),
        Positioned(
          top: DealGoSpacing.s8,
          left: DealGoSpacing.s12,
          right: DealGoSpacing.s12,
          child: Row(
            children: [
              TrackingRoundButton(
                key: const Key('tracking-back'),
                icon: DealGoIcons.back,
                onPressed: onBack,
              ),
              const SizedBox(width: DealGoSpacing.s8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: topCenter ?? const SizedBox.shrink(),
                ),
              ),
              ?topTrailing,
            ],
          ),
        ),
        DraggableScrollableSheet(
          key: const Key('tracking-sheet'),
          initialChildSize: initialSize,
          minChildSize: minSize,
          maxChildSize: 0.92,
          snap: true,
          snapSizes: [initialSize],
          builder: (context, controller) => DecoratedBox(
            decoration: BoxDecoration(
              color: DealGoColors.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x22171B2C),
                  blurRadius: 16,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: EdgeInsets.fromLTRB(
                      DealGoDimensions.pageGutter,
                      DealGoSpacing.s16,
                      DealGoDimensions.pageGutter,
                      DealGoSpacing.s16 +
                          (footer == null
                              ? MediaQuery.paddingOf(context).bottom
                              : 0),
                    ),
                    children: sheet,
                  ),
                ),
                if (footer != null)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DealGoDimensions.pageGutter,
                        DealGoSpacing.s4,
                        DealGoDimensions.pageGutter,
                        DealGoSpacing.s8,
                      ),
                      child: footer,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class TrackingRoundButton extends StatelessWidget {
  const TrackingRoundButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DealGoColors.card,
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: DealGoColors.text, size: 20),
      ),
    );
  }
}

/// Status headline + optional ETA pill at the top of the sheet.
class TrackingHeadline extends StatelessWidget {
  const TrackingHeadline({
    required this.title,
    this.eta,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? eta;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DealGoStatusSwitcher(
                child: KeyedSubtree(
                  key: ValueKey(title),
                  child: Text(
                    title,
                    key: const Key('tracking-headline'),
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  style: textTheme.bodySmall?.copyWith(
                    color: DealGoColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        if (eta != null)
          Container(
            key: const Key('tracking-eta'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: DealGoColors.subtlePurple,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  DealGoIcons.clock,
                  size: 14,
                  color: DealGoColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  eta!,
                  style: textTheme.labelLarge?.copyWith(
                    color: DealGoColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class TrackingStep {
  const TrackingStep(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// Horizontal icon timeline; [current] < 0 means none reached yet.
class TrackingTimeline extends StatelessWidget {
  const TrackingTimeline({
    required this.steps,
    required this.current,
    this.failed = false,
    super.key,
  });

  final List<TrackingStep> steps;
  final int current;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final duration = DealGoMotion.durationFor(context, DealGoMotion.medium);
    Color lineColor(bool on) =>
        on && !failed ? DealGoColors.primary : DealGoColors.border;
    // Connectors fill in as the order advances instead of snapping.
    Widget connector(bool on) => AnimatedContainer(
      duration: duration,
      curve: DealGoMotion.standard,
      height: 2.5,
      color: lineColor(on),
    );
    // The step being worked on keeps a soft pulse until the flow ends.
    final live = !failed && current >= 0 && current < steps.length - 1;
    final children = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      final done = i <= current;
      final active = i == current;
      final color = failed
          ? DealGoColors.textTertiary
          : done
          ? DealGoColors.primary
          : DealGoColors.textTertiary;
      // Each step owns an equal column; connectors sit on the dot centre line
      // so the track never drifts away from the icons on any screen width.
      children.add(
        Expanded(
          child: Column(
            key: Key('tracking-step-$i'),
            children: [
              SizedBox(
                height: 30,
                child: Row(
                  children: [
                    Expanded(
                      child: i == 0 ? const SizedBox.shrink() : connector(done),
                    ),
                    DealGoPulse(
                      active: active && live,
                      color: DealGoColors.primary,
                      diameter: 30,
                      child: AnimatedContainer(
                        duration: duration,
                        curve: DealGoMotion.standard,
                        width: active ? 30 : 24,
                        height: active ? 30 : 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done && !failed
                              ? DealGoColors.primary
                              : DealGoColors.card,
                          border: Border.all(color: color, width: 2),
                        ),
                        child: Icon(
                          steps[i].icon,
                          size: active ? 16 : 12,
                          color: done && !failed ? DealGoColors.card : color,
                        ),
                      ),
                    ),
                    Expanded(
                      child: i == steps.length - 1
                          ? const SizedBox.shrink()
                          : connector(i < current),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  steps[i].label,
                  maxLines: 2,
                  softWrap: true,
                  textAlign: TextAlign.center,
                  style: textTheme.labelSmall?.copyWith(
                    height: 1.2,
                    color: active
                        ? DealGoColors.text
                        : DealGoColors.textSecondary,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// Thin divider-separated section inside the sheet.
class TrackingSection extends StatelessWidget {
  const TrackingSection({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: DealGoSpacing.s12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: DealGoColors.divider)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: DealGoSpacing.s12),
          child: child,
        ),
      ),
    );
  }
}

/// Compact "big code" row (pickup code / delivery code).
class TrackingCodeRow extends StatelessWidget {
  const TrackingCodeRow({
    required this.icon,
    required this.label,
    required this.code,
    this.codeKey,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String code;
  final Key? codeKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: DealGoColors.greenSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: DealGoColors.brandGreen, size: 20),
            const SizedBox(width: DealGoSpacing.s8),
            Expanded(child: Text(label, style: textTheme.bodyMedium)),
            Text(
              code,
              key: codeKey,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
                color: DealGoColors.brandGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
