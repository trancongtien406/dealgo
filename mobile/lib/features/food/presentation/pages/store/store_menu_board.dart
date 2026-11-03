part of '../food_store_page.dart';

class _MenuBoard extends StatefulWidget {
  const _MenuBoard({required this.store, required this.sections, super.key});

  final FoodStoreDetail store;
  final List<_MenuGroup> sections;

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
    final scroll = _scroll;
    setState(() {
      _activeId = id;
      _jumping = true;
    });
    final target = _sectionKeys[id]?.currentContext?.findRenderObject();
    if (scroll == null || !scroll.hasClients) {
      _jumping = false;
      return;
    }
    final offset = target == null
        ? scroll.position.maxScrollExtent
        : RenderAbstractViewport.of(target).getOffsetToReveal(target, 0).offset;
    final to = offset.clamp(0.0, scroll.position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      scroll.jumpTo(to);
      _jumping = false;
    } else {
      scroll
          .animateTo(
            to,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() => _jumping = false);
    }
  }

  void _syncActiveSection() {
    final scroll = _scroll;
    if (!mounted || _jumping || scroll == null || !scroll.hasClients) return;
    final position = scroll.position;
    final threshold = position.pixels + 12;
    String? active;
    for (final section in widget.sections) {
      final target = _sectionKeys[section.id]?.currentContext
          ?.findRenderObject();
      if (target == null) continue;
      final offset = RenderAbstractViewport.of(target)
          .getOffsetToReveal(target, 0)
          .offset;
      if (offset <= threshold) active = section.id;
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
    final best = foodBestSellerIds(store.items);
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
                bestSeller: best.contains(item.id),
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
          ),
        ),
        Expanded(
          // Built eagerly so a rail tap can scroll to any section, including
          // ones still below the fold.
          child: SingleChildScrollView(
            key: const Key('food-menu-items'),
            controller: _scroll,
            padding: dealGoScrollPadding(
              context,
              const EdgeInsets.fromLTRB(
                DealGoSpacing.s8,
                DealGoSpacing.s12,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s24 + kFoodCartBarRoom,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
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
    super.key,
  });

  final FoodStoreDetail store;
  final List<_MenuGroup> groups;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final best = foodBestSellerIds(store.items);
    final padding = dealGoScrollPadding(
      context,
      const EdgeInsets.fromLTRB(
        DealGoDimensions.pageGutter,
        DealGoSpacing.s12,
        DealGoDimensions.pageGutter,
        DealGoSpacing.s24 + kFoodCartBarRoom,
      ),
    );
    if (store.items.isEmpty) {
      return ListView(
        padding: padding,
        children: [FoodPanel(child: Text(l10n.foodStoreNoItems))],
      );
    }
    if (groups.isEmpty) {
      return ListView(
        padding: padding,
        children: [
          FoodPanel(
            key: const Key('food-store-search-empty'),
            child: Text(l10n.foodStoreSearchNone),
          ),
        ],
      );
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
                bestSeller: best.contains(item.id),
              ),
            ),
          )
          ..add(const SizedBox(height: DealGoSpacing.s12));
      }
    }
    return ListView(padding: padding, children: rows);
  }
}

/// Scrolling page for the tab bodies that are laid out as one column.
class _ScrollBody extends StatelessWidget {
  const _ScrollBody({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: dealGoScrollPadding(
        context,
        const EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s12,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s24 + kFoodCartBarRoom,
        ),
      ),
      children: [child],
    );
  }
}
