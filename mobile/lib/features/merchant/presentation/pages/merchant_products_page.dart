import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/design_system/components/dealgo_card.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../food/presentation/widgets/food_badges.dart';
import '../../../food/presentation/widgets/food_category_tile.dart';
import '../../domain/usecases/create_merchant_catalog_item.dart';
import '../../domain/usecases/get_merchant_catalog.dart';
import '../../domain/usecases/set_merchant_item_availability.dart';
import '../cubit/merchant_catalog_cubit.dart';
import '../utils/merchant_routes.dart';
import '../widgets/merchant_widgets.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/components/dealgo_nav_insets.dart';
import '../../../../core/design_system/components/dealgo_network_image.dart';

class MerchantProductsPage extends StatelessWidget {
  const MerchantProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MerchantCatalogCubit(
        getMerchantCatalog: context.read<GetMerchantCatalog>(),
        createMerchantCatalogItem: context.read<CreateMerchantCatalogItem>(),
        setMerchantItemAvailability: context
            .read<SetMerchantItemAvailability>(),
      )..load(merchantAccessToken(context)),
      child: const _MerchantProductsView(),
    );
  }
}

class _MerchantProductsView extends StatelessWidget {
  const _MerchantProductsView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BlocListener<MerchantCatalogCubit, MerchantCatalogState>(
      listenWhen: (previous, current) {
        final prevError = previous is MerchantCatalogReady
            ? previous.actionError
            : null;
        final nextError = current is MerchantCatalogReady
            ? current.actionError
            : null;
        return nextError != null && nextError != prevError;
      },
      listener: (context, state) {
        if (state is! MerchantCatalogReady || state.actionError == null) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              state.actionError!.resolve(AppLocalizations.of(context)),
            ),
          ),
        );
        context.read<MerchantCatalogCubit>().clearActionError();
      },
      child: Builder(
        builder: (context) {
          final state = context.watch<MerchantCatalogCubit>().state;
          final ready = state is MerchantCatalogReady ? state : null;
          final creating = ready?.busyItemId == '_create';
          return MerchantPageFrame(
            title: AppLocalizations.of(context).foodStoreTabMenu,
            showBack: false,
            footer: ready == null
                ? null
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DealGoDimensions.pageGutter,
                      DealGoSpacing.s8,
                      DealGoDimensions.pageGutter,
                      DealGoSpacing.s16,
                    ),
                    child: DealGoPrimaryButton(
                      key: const Key('merchant-products-add'),
                      label: AppLocalizations.of(context).merchantAddItem,
                      enabled: ready.busyItemId == null,
                      isLoading: creating,
                      trailingIcon: DealGoIcons.add,
                      onPressed: () =>
                          _showAddItemDialog(context, ready.busyItemId != null),
                    ),
                  ),
            body: switch (state) {
              MerchantCatalogLoading() => const DealGoSkeletonList(
                itemCount: 4,
              ),
              MerchantCatalogFailed(:final message) => DealGoStateView.failure(
                context,
                onRetry: () => context.read<MerchantCatalogCubit>().load(
                  merchantAccessToken(context),
                ),
                cause: message.error,
                message: message.resolve(AppLocalizations.of(context)),
              ),
              MerchantCatalogReady(:final store, :final busyItemId) =>
                _CatalogBody(
                  store: store,
                  busyItemId: busyItemId,
                  textTheme: textTheme,
                ),
            },
          );
        },
      ),
    );
  }
}

Future<void> _showAddItemDialog(BuildContext context, bool busy) async {
  if (busy) return;
  final cubit = context.read<MerchantCatalogCubit>();
  final token = merchantAccessToken(context);
  // The dialog owns its controllers: disposing them here while the route was
  // still animating out crashed the app on Save.
  final result = await showDialog<({String name, String price})>(
    context: context,
    builder: (_) => const MerchantAddItemDialog(),
  );
  if (result == null || !context.mounted) {
    return;
  }
  final price = int.tryParse(result.price);
  if (price == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).merchantPriceInvalid),
      ),
    );
    return;
  }
  await cubit.createItem(
    accessToken: token,
    name: result.name,
    priceVnd: price,
  );
}

@visibleForTesting
class MerchantAddItemDialog extends StatefulWidget {
  const MerchantAddItemDialog({super.key});

  @override
  State<MerchantAddItemDialog> createState() => _MerchantAddItemDialogState();
}

class _MerchantAddItemDialogState extends State<MerchantAddItemDialog> {
  final _name = TextEditingController();
  final _price = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.merchantAddItem),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DealGoTextField(
            label: l10n.merchantItemName,
            fieldKey: const Key('merchant-catalog-name'),
            controller: _name,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: DealGoSpacing.s12),
          DealGoTextField(
            label: l10n.merchantItemPrice,
            fieldKey: const Key('merchant-catalog-price'),
            controller: _price,
            hint: '45000',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const Key('merchant-catalog-create'),
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop((name: _name.text, price: _price.text));
          },
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

class _CatalogBody extends StatefulWidget {
  const _CatalogBody({
    required this.store,
    required this.busyItemId,
    required this.textTheme,
  });

  final FoodStoreDetail store;
  final String? busyItemId;
  final TextTheme textTheme;

  @override
  State<_CatalogBody> createState() => _CatalogBodyState();
}

enum _ProductFilter { all, onSale, hidden }

class _CatalogBodyState extends State<_CatalogBody> {
  final _search = TextEditingController();
  _ProductFilter _filter = _ProductFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<FoodMenuItem> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return [
      for (final item in widget.store.items)
        if ((_filter == _ProductFilter.all) ||
            (_filter == _ProductFilter.onSale && item.available) ||
            (_filter == _ProductFilter.hidden && !item.available))
          if (q.isEmpty ||
              item.name.toLowerCase().contains(q) ||
              (item.description?.toLowerCase().contains(q) ?? false))
            item,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final catalog = widget.store.items;
    final available = catalog.where((item) => item.available).length;
    final hidden = catalog.length - available;
    final l10n = AppLocalizations.of(context);
    final textTheme = widget.textTheme;
    final filtered = _filtered;
    return ListView(
      padding: dealGoScrollPadding(context, merchantPagePadding),
      children: [
        DealGoCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.store.name, style: textTheme.titleMedium),
                    Text(
                      l10n.merchantMenuSummary(available, catalog.length),
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              DealGoChip(
                label: '$available ${l10n.merchantProductsFilterOnSale}',
                tone: DealGoChipTone.success,
              ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('merchant-open-categories'),
                onPressed: () => context.push(MerchantRoutes.categories),
                child: Text(l10n.merchantProductsCategories),
              ),
            ),
            const SizedBox(width: DealGoSpacing.s8),
            Expanded(
              child: OutlinedButton(
                key: const Key('merchant-open-history'),
                onPressed: () => context.push(MerchantRoutes.history),
                child: Text(l10n.merchantProductsHistory),
              ),
            ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s12),
        DealGoTextField(
          label: l10n.merchantProductsSearch,
          showLabel: false,
          hint: l10n.merchantProductsSearch,
          prefixIcon: DealGoIcons.search,
          controller: _search,
          fieldKey: const Key('merchant-products-search'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: DealGoSpacing.s12),
        DealGoSegmentedControl(
          key: const Key('merchant-products-filters'),
          value: _filter.name,
          onChanged: (id) => setState(
            () =>
                _filter = _ProductFilter.values.firstWhere((e) => e.name == id),
          ),
          items: [
            DealGoSegmentItem(
              id: 'all',
              label: '${l10n.merchantProductsFilterAll} (${catalog.length})',
            ),
            DealGoSegmentItem(
              id: 'onSale',
              label: '${l10n.merchantProductsFilterOnSale} ($available)',
            ),
            DealGoSegmentItem(
              id: 'hidden',
              label: '${l10n.merchantProductsFilterHidden} ($hidden)',
            ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s16),
        Text(l10n.checkoutItems, style: textTheme.titleMedium),
        const SizedBox(height: DealGoSpacing.s12),
        if (filtered.isEmpty)
          Text(
            catalog.isEmpty
                ? l10n.merchantProductsEmptyMenu
                : l10n.merchantProductsEmptyFilter,
            key: const Key('merchant-products-empty'),
            style: textTheme.bodyMedium,
          )
        else
          for (final item in filtered) ...[
            _ProductRow(
              item: item,
              busy: widget.busyItemId == item.id,
              enabled: widget.busyItemId == null,
            ),
            const SizedBox(height: DealGoSpacing.s12),
          ],
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.item,
    required this.busy,
    required this.enabled,
  });

  final FoodMenuItem item;
  final bool busy;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final imageUrl = resolveMediaUrl(item.imageUrl);
    final fallback = const ColoredBox(
      color: DealGoColors.subtlePurple,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Icon(DealGoIcons.restaurant, color: DealGoColors.primary),
      ),
    );
    return DealGoCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? DealGoNetworkImage(
                    imageUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    fallback: fallback,
                  )
                : Image.asset(
                    foodPlaceholderImage,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => fallback,
                  ),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: textTheme.titleMedium),
                FoodPriceText(
                  key: Key('merchant-product-price-${item.id}'),
                  priceVnd: item.priceVnd,
                  originalPriceVnd: item.originalPriceVnd,
                  size: 14,
                ),
                if (item.soldCount > 0)
                  Text(
                    AppLocalizations.of(context)
                        .merchantProductsSoldCount('${item.soldCount}'),
                    style: textTheme.bodySmall?.copyWith(
                      color: DealGoColors.textSecondary,
                    ),
                  ),
                Wrap(
                  spacing: 4,
                  children: [
                    TextButton(
                      key: Key('merchant-open-edit-${item.id}'),
                      onPressed: enabled
                          ? () async {
                              final changed = await context.push<bool>(
                                MerchantRoutes.itemEdit(item.id),
                                extra: item,
                              );
                              if (changed == true && context.mounted) {
                                context.read<MerchantCatalogCubit>().load(
                                  merchantAccessToken(context),
                                );
                              }
                            }
                          : null,
                      child: Text(
                        AppLocalizations.of(context).merchantProductsEdit,
                      ),
                    ),
                    TextButton(
                      key: Key('merchant-open-variants-${item.id}'),
                      onPressed: enabled
                          ? () => context.push(
                              MerchantRoutes.itemVariants(
                                item.id,
                                itemName: item.name,
                              ),
                            )
                          : null,
                      child: Text(
                        AppLocalizations.of(context).merchantVariantsCta,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                DealGoChip(
                  label: item.available
                      ? AppLocalizations.of(context).merchantItemOnSale
                      : AppLocalizations.of(context).merchantItemSoldOut,
                  tone: item.available
                      ? DealGoChipTone.success
                      : DealGoChipTone.neutral,
                ),
                Switch(
                  key: Key('merchant-catalog-available-${item.id}'),
                  value: item.available,
                  onChanged: enabled
                      ? (value) => context
                            .read<MerchantCatalogCubit>()
                            .setAvailability(
                              accessToken: merchantAccessToken(context),
                              itemId: item.id,
                              available: value,
                            )
                      : null,
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return DealGoColors.card;
                    }
                    return DealGoColors.textSecondary;
                  }),
                  trackColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return DealGoColors.brandGreen;
                    }
                    return DealGoColors.border;
                  }),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
