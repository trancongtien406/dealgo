import 'package:flutter/material.dart';

import '../tokens/dealgo_tokens.dart';

class DealGoSegmentItem {
  const DealGoSegmentItem({required this.id, required this.label});

  final String id;
  final String label;
}

/// Exclusive filter / period segments. Prefer this over Material FilterChip.
class DealGoSegmentedControl extends StatelessWidget {
  const DealGoSegmentedControl({
    required this.items,
    required this.value,
    required this.onChanged,
    this.scrollable = true,
    super.key,
  });

  final List<DealGoSegmentItem> items;
  final String value;
  final ValueChanged<String> onChanged;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: DealGoSpacing.s8),
          _SegmentPill(
            item: items[i],
            selected: items[i].id == value,
            expanded: !scrollable,
            onTap: () {
              if (items[i].id != value) {
                onChanged(items[i].id);
              }
            },
          ),
        ],
      ],
    );

    if (!scrollable) {
      return row;
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: row,
    );
  }
}

class _SegmentPill extends StatelessWidget {
  const _SegmentPill({
    required this.item,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final DealGoSegmentItem item;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(
      side: BorderSide(
        color: selected ? DealGoColors.primary : DealGoColors.border,
      ),
    );
    final pill = Material(
      color: selected ? DealGoColors.primary : DealGoColors.card,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: DealGoDimensions.minTapTarget,
            minWidth: DealGoDimensions.minTapTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DealGoSpacing.s16),
            child: Center(
              child: Text(
                item.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? Colors.white : DealGoColors.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: expanded ? Expanded(child: pill) : pill,
    );
  }
}
