import 'package:flutter/material.dart';

import '../tokens/dealgo_tokens.dart';

class DealGoSegmentItem {
  const DealGoSegmentItem({required this.id, required this.label});

  final String id;
  final String label;
}

/// Exclusive filter segments. The selected item is a static plate.
///
/// Default: equal-width items that fill the track (3–4 filters).
/// Set [scrollable] for many labels that must size to content.
class DealGoSegmentedControl extends StatelessWidget {
  const DealGoSegmentedControl({
    required this.items,
    required this.value,
    required this.onChanged,
    this.scrollable = false,
    super.key,
  });

  final List<DealGoSegmentItem> items;
  final String value;
  final ValueChanged<String> onChanged;

  /// When true, segments size to labels and scroll horizontally.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = items.indexWhere((item) => item.id == value);
    final index = selectedIndex < 0 ? 0 : selectedIndex;

    final row = Row(
      mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: DealGoSpacing.s4),
          if (scrollable)
            _SegmentPill(
              item: items[i],
              selected: i == index,
              onTap: () {
                if (items[i].id != items[index].id) {
                  onChanged(items[i].id);
                }
              },
            )
          else
            Expanded(
              child: _SegmentPill(
                item: items[i],
                selected: i == index,
                onTap: () {
                  if (items[i].id != items[index].id) {
                    onChanged(items[i].id);
                  }
                },
              ),
            ),
        ],
      ],
    );

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
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: row,
                )
              : row,
        ),
      ),
    );
  }
}

class _SegmentPill extends StatelessWidget {
  const _SegmentPill({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final DealGoSegmentItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(DealGoRadius.input);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? DealGoColors.primary : Colors.transparent,
          borderRadius: radius,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
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
                    child: Text(
                      item.label,
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.center,
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
