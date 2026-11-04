part of '../food_store_page.dart';

class _MenuBoard extends StatefulWidget {
  const _MenuBoard({
    required this.store,
    required this.sections,
    required this.outerScroll,
    required this.pinnedKey,
    required this.headerOverlap,
    super.key,
  });

  final FoodStoreDetail store;
  final List<_MenuGroup> sections;

  /// Outer controller of the store's [NestedScrollView]. A rail tap has to
  /// collapse the store header before the section offset can be measured.
  final ScrollController outerScroll;

  /// The pinned tabs/search header, used as the target line for a jump.
  final GlobalKey pinnedKey;

  /// Height the pinned bar takes from both lists, so neither starts behind it.
  final SliverOverlapAbsorberHandle headerOverlap;

  @override
  State<_MenuBoard> createState() => _MenuBoardState();
}

class _MenuBoardState extends State<_MenuBoard> {
  final Map<String, GlobalKey> _sectionKeys = {};
  late String _activeId = widget.sections.first.id;
  ScrollController? _scroll;
  var _jumping = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inside the store's NestedScrollView this is the inner controller, so a
    // drag here still collapses the store header first.
    final controller = PrimaryScrollController.maybeOf(context);
    if (identical(controller, _scroll)) return;
    _scroll?.removeListener(_syncActiveSection);
    _scroll = controller;
    _scroll?.addListener(_syncActiveSection);
  }

  @override
  void dispose() {
    _scroll?.removeListener(_syncActiveSection);
    super.dispose();
  }

  void _jumpTo(String id) {
    setState(() {
      _activeId = id;
      _jumping = true;
    });
    final outer = widget.outerScroll;
    if (!outer.hasClients ||
        outer.position.pixels >= outer.position.maxScrollExtent - 0.5) {
      _scrollToSection(id);
      return;
    }
    // While the store header is expanded the menu viewport is only the thin
    // strip below it, so the measured offset would land the section under the
    // pinned tabs. Collapse the header first, then measure.
    outer
        .animateTo(
          outer.position.maxScrollExtent,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          if (!mounted) return;
          // The final animation tick only marks layout dirty; wait for the
          // collapsed frame before measuring the pinned header position.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToSection(id);
          });
        });
  }

  void _scrollToSection(String id) {
    final scroll = _scroll;
    final sectionContext = _sectionKeys[id]?.currentContext;
    if (scroll == null || !scroll.hasClients || sectionContext == null) {
      _jumping = false;
      return;
    }
    final to = _sectionTopOffset(scroll.position, sectionContext);
    if (to == null) {
      _jumping = false;
      return;
    }
    final target = to.clamp(0.0, scroll.position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      scroll.jumpTo(target);
      _jumping = false;
      return;
    }
    scroll
        .animateTo(
          target,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() => _jumping = false);
  }

  /// Scroll offset that puts [sectionContext] right below the pinned header.
  double? _sectionTopOffset(ScrollPosition position, BuildContext section) {
    final target = section.findRenderObject();
    if (target is! RenderBox || !target.attached) return null;
    final pinned = _pinnedBottom;
    if (pinned == null) {
      final viewport = RenderAbstractViewport.maybeOf(target);
      return viewport?.getOffsetToReveal(target, 0).offset;
    }
    return position.pixels + target.localToGlobal(Offset.zero).dy - pinned;
  }

  double? get _pinnedBottom {
    final pinned = widget.pinnedKey.currentContext?.findRenderObject();
    if (pinned is! RenderBox || !pinned.attached) return null;
    return pinned.localToGlobal(Offset.zero).dy + pinned.size.height;
  }

  void _syncActiveSection() {
    final scroll = _scroll;
    if (!mounted || _jumping || scroll == null || !scroll.hasClients) return;
    final position = scroll.position;
    final pinned = _pinnedBottom;
    final threshold = (pinned ?? 0) + 12;
    String? active;
    for (final section in widget.sections) {
      final target = _sectionKeys[section.id]?.currentContext
          ?.findRenderObject();
      if (target is! RenderBox || !target.attached) continue;
      if (target.localToGlobal(Offset.zero).dy <= threshold) {
        active = section.id;
      }
    }
    if (position.pixels >= position.maxScrollExtent - 1) {
      active = widget.sections.last.id;
    }
    if (active != null && active != _activeId) {
      setState(() => _activeId = active!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final rows = <Widget>[];
    var index = 0;
    for (final section in widget.sections) {
      rows
        ..add(
          Padding(
            key: _sectionKeys.putIfAbsent(section.id, GlobalKey.new),
            padding: const EdgeInsets.only(
              top: DealGoSpacing.s4,
              bottom: DealGoSpacing.s8,
              left: 2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    section.title!,
                    key: Key('food-menu-section-${section.id}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s8),
                Text(
                  l10n.foodStoreSectionCount(section.items.length),
                  style: textTheme.labelSmall?.copyWith(
                    color: DealGoColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        )
        ..addAll([
          for (final item in section.items) ...[
            DealGoStaggerIn(
              index: index++,
              child: _MenuItem(
                key: Key('food-menu-${section.id}-${item.id}'),
                store: store,
                item: item,
                featured: section.id == 'best',
                compact: true,
              ),
            ),
            const SizedBox(height: DealGoSpacing.s12),
          ],
        ]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: _menuRailWidth,
          child: _CategoryRail(
            sections: widget.sections,
            activeId: _activeId,
            onSelected: _jumpTo,
            pinnedKey: widget.pinnedKey,
            headerOverlap: widget.headerOverlap,
          ),
        ),
        Expanded(
          // Built eagerly so a rail tap can scroll to any section, including
          // ones still below the fold: a lazy list would not lay out the
          // section keys the jump measures.
          child: CustomScrollView(
            key: const Key('food-menu-items'),
            controller: _scroll,
            slivers: [
              SliverOverlapInjector(handle: widget.headerOverlap),
              SliverPadding(
                padding: dealGoScrollPadding(
                  context,
                  const EdgeInsets.fromLTRB(
                    DealGoSpacing.s8,
                    DealGoSpacing.s16,
                    DealGoDimensions.pageGutter,
                    DealGoSpacing.s24 + kFoodCartBarRoom,
                  ),
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: rows,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One flat list: in-store search results, or a store whose menu has a single
/// unnamed section.
class _MenuList extends StatelessWidget {
  const _MenuList({
    required this.store,
    required this.groups,
    required this.searching,
    required this.headerOverlap,
    super.key,
  });

  final FoodStoreDetail store;
  final List<_MenuGroup> groups;
  final bool searching;
  final SliverOverlapAbsorberHandle headerOverlap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final padding = dealGoScrollPadding(
      context,
      const EdgeInsets.fromLTRB(
        DealGoDimensions.pageGutter,
        DealGoSpacing.s16,
        DealGoDimensions.pageGutter,
        DealGoSpacing.s24 + kFoodCartBarRoom,
      ),
    );
    Widget list(List<Widget> children) => CustomScrollView(
      slivers: [
        SliverOverlapInjector(handle: headerOverlap),
        SliverPadding(
          padding: padding,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
    if (store.items.isEmpty) {
      return list([FoodPanel(child: Text(l10n.foodStoreNoItems))]);
    }
    if (groups.isEmpty) {
      return list([
        FoodPanel(
          key: const Key('food-store-search-empty'),
          child: Text(l10n.foodStoreSearchNone),
        ),
      ]);
    }
    final rows = <Widget>[];
    var index = 0;
    for (final group in groups) {
      if (group.title != null || !searching) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(
              top: DealGoSpacing.s4,
              bottom: DealGoSpacing.s8,
              left: 2,
            ),
            child: Text(
              group.title == null
                  ? l10n.foodStoreMenuCount(group.items.length)
                  : '${group.title} (${group.items.length})',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      }
      for (final item in group.items) {
        rows
          ..add(
            DealGoStaggerIn(
              index: index++,
              child: _MenuItem(
                key: Key('food-menu-${group.id}-${item.id}'),
                store: store,
                item: item,
                featured: group.id == 'best',
              ),
            ),
          )
          ..add(const SizedBox(height: DealGoSpacing.s12));
      }
    }
    return list(rows);
  }
}

/// Scrolling page for the tab bodies that are laid out as one column.
class _ScrollBody extends StatelessWidget {
  const _ScrollBody({
    required this.headerOverlap,
    required this.child,
    super.key,
  });

  final SliverOverlapAbsorberHandle headerOverlap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverOverlapInjector(handle: headerOverlap),
        SliverPadding(
          padding: dealGoScrollPadding(
            context,
            const EdgeInsets.fromLTRB(
              DealGoDimensions.pageGutter,
              DealGoSpacing.s16,
              DealGoDimensions.pageGutter,
              DealGoSpacing.s24 + kFoodCartBarRoom,
            ),
          ),
          sliver: SliverToBoxAdapter(child: child),
        ),
      ],
    );
  }
}
