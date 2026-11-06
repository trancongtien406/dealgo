import 'package:flutter/material.dart';

import '../../motion/dealgo_motion.dart';
import '../tokens/dealgo_tokens.dart';

class DealGoSegmentItem {
  const DealGoSegmentItem({required this.id, required this.label, this.key});

  final String id;
  final String label;

  /// Optional key on the tappable segment.
  final Key? key;
}

/// Exclusive filter segments. The selected plate slides between the equal-width
/// segments, so a change reads as one moving control instead of the background
/// jumping from one label to the next.
///
/// Set [scrollable] when many labels must size to their content; that track
/// keeps the plate inside the selected pill, which has no shared slot geometry.
class DealGoSegmentedControl extends StatelessWidget {
  const DealGoSegmentedControl({
    required this.items,
    required this.value,
    required this.onChanged,
    this.scrollable = false,
    this.enabled = true,
    super.key,
  });

  final List<DealGoSegmentItem> items;
  final String value;
  final ValueChanged<String> onChanged;

  /// When true, segments size to labels and scroll horizontally.
  final bool scrollable;

  /// False while the owning form is submitting: the plate stays, taps are off.
  final bool enabled;

  void _select(int index) {
    if (!enabled || items[index].id == value) {
      return;
    }
    onChanged(items[index].id);
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final selectedIndex = items.indexWhere((item) => item.id == value);
    final index = selectedIndex < 0 ? 0 : selectedIndex;
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: DealGoColors.canvas,
          borderRadius: BorderRadius.circular(DealGoRadius.input),
          border: Border.all(color: DealGoColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(DealGoSpacing.s4),
          child: scrollable
              ? _scrollableTrack(context, index)
              : _equalWidthTrack(context, index),
        ),
      ),
    );
  }

  Widget _scrollableTrack(BuildContext context, int index) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: DealGoSpacing.s4),
            _SegmentPill(
              key: items[i].key,
              item: items[i],
              selected: i == index,
              enabled: enabled,
              showPlate: true,
              onTap: () => _select(i),
            ),
          ],
        ],
      ),
    );
  }

  Widget _equalWidthTrack(BuildContext context, int index) {
    const gap = DealGoSpacing.s4;
    final duration = DealGoMotion.durationFor(context, DealGoMotion.medium);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            (constraints.maxWidth - gap * (items.length - 1)) / items.length;
        final left = rtl
            ? constraints.maxWidth - (index + 1) * width - index * gap
            : index * (width + gap);
        return Stack(
          children: [
            AnimatedPositioned(
              duration: duration,
              curve: DealGoMotion.standard,
              left: left,
              top: 0,
              bottom: 0,
              width: width,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: DealGoColors.primary,
                  borderRadius: BorderRadius.circular(DealGoRadius.input),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  Expanded(
                    child: _SegmentPill(
                      key: items[i].key,
                      item: items[i],
                      selected: i == index,
                      enabled: enabled,
                      showPlate: false,
                      onTap: () => _select(i),
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SegmentPill extends StatelessWidget {
  const _SegmentPill({
    required this.item,
    required this.selected,
    required this.enabled,
    required this.showPlate,
    required this.onTap,
    super.key,
  });

  final DealGoSegmentItem item;
  final bool selected;
  final bool enabled;
  final bool showPlate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(DealGoRadius.input);
    final duration = DealGoMotion.durationFor(context, DealGoMotion.medium);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: AnimatedContainer(
        duration: showPlate ? duration : Duration.zero,
        curve: DealGoMotion.standard,
        decoration: BoxDecoration(
          color: showPlate && selected
              ? DealGoColors.primary
              : Colors.transparent,
          borderRadius: radius,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: radius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: DealGoDimensions.minTapTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DealGoSpacing.s8,
                ),
                // Equal-width segments on a 320 pt phone: shrink the label
                // ("Ẩn / nháp (1)") rather than cut the count off.
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedDefaultTextStyle(
                      duration: duration,
                      curve: DealGoMotion.standard,
                      style:
                          (Theme.of(context).textTheme.labelSmall ??
                                  const TextStyle())
                              .copyWith(
                                color: selected
                                    ? Colors.white
                                    : DealGoColors.text,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                      child: Text(
                        item.label,
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
