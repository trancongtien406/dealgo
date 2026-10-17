import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_illustration.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../identity/presentation/widgets/auth_widgets.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/usecases/list_food_stores.dart';
import '../cubit/food_discovery_cubit.dart';
import '../utils/food_routes.dart';
import '../widgets/food_widgets.dart';

class FoodDiscoveryPage extends StatelessWidget {
  const FoodDiscoveryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          FoodDiscoveryCubit(listFoodStores: context.read<ListFoodStores>())
            ..load(currentAccessToken(context)),
      child: const _FoodDiscoveryView(),
    );
  }
}

class _FoodDiscoveryView extends StatefulWidget {
  const _FoodDiscoveryView();

  @override
  State<_FoodDiscoveryView> createState() => _FoodDiscoveryViewState();
}

class _FoodDiscoveryViewState extends State<_FoodDiscoveryView> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _storesKey = GlobalKey();
  var _category = 'Gần tôi';

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _reload() {
    context.read<FoodDiscoveryCubit>().load(currentAccessToken(context));
  }

  void _openStore(FoodStoreSummary store) {
    context.push(FoodRoutes.store(store.id));
  }

  void _scrollToStores() {
    final target = _storesKey.currentContext;
    if (target == null) {
      return;
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    Scrollable.ensureVisible(
      target,
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final discovery = context.watch<FoodDiscoveryCubit>().state;
    final stores = switch (discovery) {
      FoodDiscoveryReady(:final stores) => stores,
      _ => const <FoodStoreSummary>[],
    };
    final loading = discovery is FoodDiscoveryLoading;
    final error = discovery is FoodDiscoveryFailed ? discovery.message : null;
    final visible = stores;
    return SafeArea(
      bottom: false,
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s8,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s24,
        ),
        children: [
          const _DiscoveryHeader(),
          const SizedBox(height: DealGoSpacing.s16),
          InkWell(
            onTap: () => context.push(FoodRoutes.search),
            borderRadius: BorderRadius.circular(DealGoRadius.input),
            child: InputDecorator(
              decoration: InputDecoration(
                hintText: 'Tìm quán ăn, món ngon, đồ uống...',
                hintStyle: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: DealGoColors.textSecondary),
                filled: true,
                fillColor: DealGoColors.card,
                prefixIcon: const Icon(
                  Icons.search,
                  color: DealGoColors.primary,
                ),
                suffixIcon: const Icon(Icons.tune, color: DealGoColors.primary),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: DealGoSpacing.s12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DealGoRadius.input),
                  borderSide: const BorderSide(color: DealGoColors.border),
                ),
              ),
              child: Text(
                'Tìm quán ăn, món ngon, đồ uống...',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: DealGoColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(height: DealGoSpacing.s16),
          _FoodBanner(onExplore: _scrollToStores),
          const SizedBox(height: DealGoSpacing.s16),
          _CategoryStrip(
            selected: _category,
            onSelected: (label) {
              setState(() => _category = label);
              context.push(
                '${FoodRoutes.category}?name=${Uri.encodeQueryComponent(label)}',
              );
            },
          ),
          const SizedBox(height: DealGoSpacing.s20),
          _SectionHeader(
            title: 'Quán ngon gần bạn',
            subtitle: 'Gợi ý tại Hải Châu, Đà Nẵng',
            onSeeAll: _scrollToStores,
          ),
          const SizedBox(height: DealGoSpacing.s12),
          _StoreResults(
            key: _storesKey,
            loading: loading,
            error: error,
            stores: visible,
            onRetry: _reload,
            onOpen: _openStore,
          ),
          if (visible.isNotEmpty) ...[
            const SizedBox(height: DealGoSpacing.s20),
            _SectionHeader(
              title: 'Đặt nhiều tuần này',
              subtitle: 'Món ngon được yêu thích',
              onSeeAll: _scrollToStores,
            ),
            const SizedBox(height: DealGoSpacing.s12),
            for (final store in visible) ...[
              _WideStoreCard(store: store, onTap: () => _openStore(store)),
              const SizedBox(height: DealGoSpacing.s12),
            ],
          ],
        ],
      ),
    );
  }
}

class _DiscoveryHeader extends StatelessWidget {
  const _DiscoveryHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: DealGoWordmark()),
        _LocationChip(),
        SizedBox(width: DealGoSpacing.s8),
        CircleAvatar(
          radius: 18,
          backgroundColor: DealGoColors.subtlePurple,
          child: Icon(Icons.person, color: DealGoColors.primary, size: 20),
        ),
      ],
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.subtlePurple,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DealGoSpacing.s12,
          vertical: DealGoSpacing.s8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.place, color: DealGoColors.primary, size: 16),
            const SizedBox(width: 2),
            Text(
              'Đà Nẵng',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: DealGoColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodBanner extends StatelessWidget {
  const _FoodBanner({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DealGoRadius.card),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3B0764), Color(0xFF7C3AED), Color(0xFFEA580C)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(DealGoSpacing.s16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DEAL ĐỒ ĂN HÔM NAY',
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s4),
                    Text(
                      'Ăn ngon mỗi ngày,\ntiết kiệm đến 50%',
                      style: textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        onPressed: onExplore,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: DealGoColors.primary,
                          elevation: 0,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(
                            horizontal: DealGoSpacing.s16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text('Khám phá ngay →'),
                      ),
                    ),
                  ],
                ),
              ),
              const DealGoIllustration(
                'assets/illustrations/card_food.svg',
                width: 88,
                height: 88,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const categories = <_FoodCategory>[
      _FoodCategory(
        'Gần tôi',
        Icons.place,
        Color(0xFFF3EAFF),
        DealGoColors.primary,
      ),
      _FoodCategory(
        'Món Việt',
        Icons.ramen_dining,
        Color(0xFFFFF1E6),
        Color(0xFFEA580C),
      ),
      _FoodCategory(
        'Trà sữa',
        Icons.local_cafe,
        Color(0xFFFFEEF6),
        Color(0xFFDB2777),
      ),
      _FoodCategory(
        'Ăn nhanh',
        Icons.lunch_dining,
        Color(0xFFE7F8EC),
        DealGoColors.brandGreen,
      ),
      _FoodCategory(
        'Cà phê',
        Icons.coffee,
        Color(0xFFE8F1FF),
        Color(0xFF2563EB),
      ),
    ];
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: DealGoSpacing.s12),
        itemBuilder: (context, index) {
          final category = categories[index];
          final active = category.label == selected;
          return InkWell(
            onTap: () => onSelected(category.label),
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 68,
              child: Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: category.background,
                      shape: BoxShape.circle,
                      border: active
                          ? Border.all(color: category.color, width: 1.5)
                          : null,
                    ),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Icon(
                        category.icon,
                        color: category.color,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  Text(
                    category.label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: DealGoColors.text,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FoodCategory {
  const _FoodCategory(this.label, this.icon, this.background, this.color);

  final String label;
  final IconData icon;
  final Color background;
  final Color color;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.onSeeAll,
  });

  final String title;
  final String subtitle;
  final VoidCallback onSeeAll;

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
              Text(title, style: textTheme.titleMedium),
              Text(subtitle, style: textTheme.bodySmall),
            ],
          ),
        ),
        TextButton(
          onPressed: onSeeAll,
          style: TextButton.styleFrom(foregroundColor: DealGoColors.primary),
          child: const Text('Xem tất cả →'),
        ),
      ],
    );
  }
}

class _StoreResults extends StatelessWidget {
  const _StoreResults({
    required this.loading,
    required this.error,
    required this.stores,
    required this.onRetry,
    required this.onOpen,
    super.key,
  });

  final bool loading;
  final String? error;
  final List<FoodStoreSummary> stores;
  final VoidCallback onRetry;
  final ValueChanged<FoodStoreSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: DealGoSpacing.s24),
        child: Text('Đang tải cửa hàng'),
      );
    }
    final l10n = AppLocalizations.of(context);
    final message = switch (error) {
      'UNAUTHORIZED' => l10n.errorUnauthorized,
      'NETWORK_ERROR' => l10n.errorNetwork,
      null => null,
      _ => error,
    };
    if (message != null) {
      return FoodPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: DealGoSpacing.s12),
            TextButton(onPressed: onRetry, child: Text(l10n.actionRetry)),
          ],
        ),
      );
    }
    if (stores.isEmpty) {
      return FoodPanel(child: Text(l10n.emptyStoresNearby));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = DealGoSpacing.s12;
        final tileWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final store in stores)
              SizedBox(
                width: tileWidth,
                child: _StoreTile(
                  key: Key('food-store-card-${store.id}'),
                  store: store,
                  onTap: () => onOpen(store),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StoreTile extends StatelessWidget {
  const _StoreTile({required this.store, required this.onTap, super.key});

  final FoodStoreSummary store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DealGoColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        side: const BorderSide(color: DealGoColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 96,
              width: double.infinity,
              child: ColoredBox(
                color: Color(0xFFFFF4EA),
                child: Icon(
                  Icons.ramen_dining,
                  color: Color(0xFFEA580C),
                  size: 40,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(DealGoSpacing.s12),
              child: Text(
                store.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WideStoreCard extends StatelessWidget {
  const _WideStoreCard({required this.store, required this.onTap});

  final FoodStoreSummary store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: DealGoColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        side: const BorderSide(color: DealGoColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DealGoSpacing.s12),
          child: Row(
            children: [
              const FoodThumb(size: 72),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: textTheme.titleMedium?.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: DealGoSpacing.s4),
                    Text('Xem thực đơn', style: textTheme.bodySmall),
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
