part of '../food_store_page.dart';

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.selected,
    required this.onSelected,
    this.reviewCount,
  });

  final _StoreTab selected;
  final ValueChanged<_StoreTab> onSelected;
  final int? reviewCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final count = reviewCount;
    final tabs = <(_StoreTab, String)>[
      (_StoreTab.menu, l10n.foodStoreTabMenu),
      (
        _StoreTab.reviews,
        count != null && count > 0
            ? '${l10n.foodStoreTabReviews} ($count)'
            : l10n.foodStoreTabReviews,
      ),
      (_StoreTab.info, l10n.foodStoreTabInfo),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: DealGoColors.border)),
      ),
      child: SizedBox(
        height: _tabsHeight,
        child: Row(
          children: [
            for (final tab in tabs)
              Expanded(
                child: InkWell(
                  key: Key('food-store-tab-${tab.$1.name}'),
                  onTap: () => onSelected(tab.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: selected == tab.$1
                              ? DealGoColors.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tab.$2,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: selected == tab.$1
                              ? DealGoColors.primary
                              : DealGoColors.textSecondary,
                          fontWeight: selected == tab.$1
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuSearchBar extends StatelessWidget {
  const _MenuSearchBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(DealGoRadius.button),
      borderSide: BorderSide(color: DealGoColors.border),
    );
    return TextField(
      key: const Key('food-store-search'),
      controller: controller,
      textInputAction: TextInputAction.search,
      style: textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: l10n.foodStoreSearchMenu,
        hintStyle: textTheme.bodySmall?.copyWith(
          color: DealGoColors.textSecondary,
        ),
        prefixIcon: const Icon(
          DealGoIcons.search,
          size: 18,
          color: DealGoColors.primary,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 38,
          minHeight: 38,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                key: const Key('food-store-search-clear'),
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                onPressed: controller.clear,
                icon: const Icon(DealGoIcons.close, size: 16),
              ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 38,
          minHeight: 38,
        ),
        filled: true,
        fillColor: DealGoColors.card,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: DealGoColors.primary),
        ),
      ),
    );
  }
}

/// Vertical category index beside the menu items. The active row follows the
/// items being scrolled and is kept inside the rail.
class _CategoryRail extends StatefulWidget {
  const _CategoryRail({
    required this.sections,
    required this.activeId,
    required this.onSelected,
    required this.pinnedKey,
    required this.headerOverlap,
  });

  final List<_MenuGroup> sections;
  final String activeId;
  final ValueChanged<String> onSelected;

  /// The pinned tabs/search bar sits on top of this rail's viewport while the
  /// store header is collapsed; a revealed row must stay below it.
  final GlobalKey pinnedKey;

  /// Height the pinned bar takes from the rail, so its first row is not hidden.
  final SliverOverlapAbsorberHandle headerOverlap;

  @override
  State<_CategoryRail> createState() => _CategoryRailState();
}

class _CategoryRailState extends State<_CategoryRail> {
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _keys = {};

  @override
  void didUpdateWidget(_CategoryRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeId != widget.activeId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealActive());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _revealActive() {
    if (!mounted || !_scroll.hasClients) return;
    final row = _keys[widget.activeId]?.currentContext?.findRenderObject();
    final viewport = _scroll.position.context.storageContext.findRenderObject();
    if (row is! RenderBox || viewport is! RenderBox) return;
    final top = row.localToGlobal(Offset.zero, ancestor: viewport).dy;
    final bottom = top + row.size.height;
    const margin = DealGoSpacing.s24;
    final visibleTop = _hiddenTop(viewport) + margin;
    double? target;
    if (top < visibleTop) {
      target = _scroll.offset + top - visibleTop;
    } else if (bottom > viewport.size.height - margin) {
      target = _scroll.offset + bottom - viewport.size.height + margin;
    }
    if (target == null) return;
    _scroll.animateTo(
      target.clamp(0, _scroll.position.maxScrollExtent),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  /// Height of this rail's viewport currently covered by the pinned bar.
  double _hiddenTop(RenderBox viewport) {
    final pinned = widget.pinnedKey.currentContext?.findRenderObject();
    if (pinned is! RenderBox || !pinned.attached) return 0;
    final pinnedBottom =
        pinned.localToGlobal(Offset.zero).dy + pinned.size.height;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    return (pinnedBottom - viewportTop).clamp(0.0, viewport.size.height / 2);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.foodStoreMenuSections,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: DealGoColors.canvas,
          border: Border(right: BorderSide(color: DealGoColors.divider)),
        ),
        child: CustomScrollView(
          key: const Key('food-menu-categories'),
          controller: _scroll,
          slivers: [
            SliverOverlapInjector(handle: widget.headerOverlap),
            SliverPadding(
              padding: dealGoScrollPadding(
                context,
                const EdgeInsets.only(
                  top: DealGoSpacing.s8,
                  bottom: DealGoSpacing.s24,
                ),
              ),
              // Every category is built: a tap has to reach one that is still
              // below the rail's fold.
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    for (final section in widget.sections)
                      _railRow(context, l10n, textTheme, section),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _railRow(
    BuildContext context,
    AppLocalizations l10n,
    TextTheme textTheme,
    _MenuGroup section,
  ) {
    final active = section.id == widget.activeId;
    return KeyedSubtree(
      key: _keys.putIfAbsent(section.id, GlobalKey.new),
      child: Material(
        color: active ? DealGoColors.card : Colors.transparent,
        child: InkWell(
          key: Key('food-menu-category-${section.id}'),
          onTap: () => widget.onSelected(section.id),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: active ? DealGoColors.primary : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              DealGoSpacing.s12,
              DealGoSpacing.s12,
              DealGoSpacing.s8,
              DealGoSpacing.s12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title!,
                  key: Key('food-menu-category-label-${section.id}'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    height: 1.25,
                    color: active
                        ? DealGoColors.primary
                        : DealGoColors.textSecondary,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.foodStoreSectionCount(section.items.length),
                  style: textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    color: active
                        ? DealGoColors.primary
                        : DealGoColors.textTertiary,
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

/// Category rail on the left, the whole menu on the right: tapping a category
/// scrolls the items to it, and scrolling highlights the category in view.
