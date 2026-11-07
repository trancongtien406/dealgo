import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/api_base_url.dart';
import '../../../../core/design_system/components/dealgo_card.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_nav_insets.dart';
import '../../../../core/design_system/components/dealgo_network_image.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_refresh.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/format/text_case.dart';
import '../../../../core/motion/dealgo_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../food/presentation/widgets/food_badges.dart';
import '../../domain/entities/merchant_menu_models.dart';
import '../../domain/repositories/merchant_orders_repository.dart';
import '../../domain/usecases/create_merchant_catalog_item.dart';
import '../../domain/usecases/get_merchant_catalog.dart';
import '../../domain/usecases/set_merchant_item_availability.dart';
import '../cubit/merchant_catalog_cubit.dart';
import '../utils/merchant_routes.dart';
import '../widgets/merchant_widgets.dart';

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
        repository: context.read<MerchantOrdersRepository>(),
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
                      DealGoSpacing.s12,
                    ),
                    child: DealGoPrimaryButton(
                      key: const Key('merchant-products-add'),
                      label: AppLocalizations.of(context).merchantAddItem,
                      enabled: ready.busyItemId == null,
                      isLoading: creating,
                      trailingIcon: DealGoIcons.add,
                      onPressed: () =>
                          _openCreateItemPage(context, ready.busyItemId != null),
                    ),
                  ),
            body: switch (state) {
              MerchantCatalogLoading() => const DealGoSkeletonList(
                itemCount: 4,
              ),
              MerchantCatalogFailed(:final message) => DealGoRefresh(
                onRefresh: () => context.read<MerchantCatalogCubit>().load(
                  merchantAccessToken(context),
                ),
                child: DealGoStateView.failure(
                  context,
                  onRetry: () => context.read<MerchantCatalogCubit>().load(
                    merchantAccessToken(context),
                  ),
                  cause: message.error,
                  message: message.resolve(AppLocalizations.of(context)),
                ),
              ),
              MerchantCatalogReady(
                :final store,
                :final categories,
                :final busyItemId,
              ) =>
                _CatalogBody(
                  store: store,
                  categories: categories,
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

Future<void> _openCreateItemPage(BuildContext context, bool busy) async {
  if (busy) return;
  final changed = await context.push<bool>(MerchantRoutes.itemNew);
  if (changed == true && context.mounted) {
    await context.read<MerchantCatalogCubit>().load(
      merchantAccessToken(context),
    );
  }
}

typedef _NewItemDraft = ({
  String name,
  String price,
  String? description,
  int? prepMinutes,
  String? categoryId,
});

@visibleForTesting
class MerchantAddItemDialog extends StatefulWidget {
  const MerchantAddItemDialog({super.key, this.categories = const []});

  final List<MerchantMenuCategory> categories;

  @override
  State<MerchantAddItemDialog> createState() => _MerchantAddItemDialogState();
}

class _MerchantAddItemDialogState extends State<MerchantAddItemDialog> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _description = TextEditingController();
  final _prep = TextEditingController();
  String? _categoryId;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    _prep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final selectedCat = widget.categories
        .cast<MerchantMenuCategory?>()
        .firstWhere((c) => c?.id == _categoryId, orElse: () => null);
    return Dialog(
      backgroundColor: DealGoColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        side: BorderSide(color: DealGoColors.border),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: DealGoDimensions.pageGutter,
        vertical: DealGoSpacing.s24,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DealGoSpacing.s20,
          DealGoSpacing.s20,
          DealGoSpacing.s20,
          DealGoSpacing.s16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.merchantAddItem, style: textTheme.titleLarge),
            const SizedBox(height: DealGoSpacing.s16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
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
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    DealGoTextField(
                      label: l10n.merchantItemDescription,
                      fieldKey: const Key('merchant-catalog-description'),
                      controller: _description,
                      textInputAction: TextInputAction.next,
                      maxLines: 2,
                    ),
                    const SizedBox(height: DealGoSpacing.s12),
                    DealGoTextField(
                      label: l10n.merchantItemPrep,
                      fieldKey: const Key('merchant-catalog-prep'),
                      controller: _prep,
                      textInputAction: TextInputAction.done,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    if (widget.categories.isNotEmpty) ...[
                      const SizedBox(height: DealGoSpacing.s12),
                      InkWell(
                        key: const Key('merchant-catalog-category'),
                        onTap: () async {
                          final picked = await showCategoryPickerSheet(
                            context: context,
                            categories: widget.categories,
                            selectedId: _categoryId,
                          );
                          if (picked != null) {
                            setState(() => _categoryId = picked.$1);
                          }
                        },
                        borderRadius: BorderRadius.circular(DealGoRadius.input),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: l10n.merchantItemCategory,
                            suffixIcon: const Icon(
                              DealGoIcons.chevronDown,
                              size: 20,
                            ),
                          ),
                          child: Text(
                            selectedCat != null
                                ? capitalizeFirstLetter(selectedCat.name)
                                : '—',
                            style: textTheme.bodyLarge?.copyWith(
                              color: selectedCat != null
                                  ? null
                                  : DealGoColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: DealGoSpacing.s20),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: DealGoSecondaryButton(
                      label: l10n.actionCancel,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s12),
                  Expanded(
                    child: DealGoPrimaryButton(
                      key: const Key('merchant-catalog-create'),
                      label: l10n.actionSave,
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        final description = _description.text.trim();
                        Navigator.of(context).pop<_NewItemDraft>((
                          name: _name.text,
                          price: _price.text,
                          description: description.isEmpty ? null : description,
                          prepMinutes: int.tryParse(_prep.text.trim()),
                          categoryId: _categoryId,
                        ));
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogBody extends StatefulWidget {
  const _CatalogBody({
    required this.store,
    required this.categories,
    required this.busyItemId,
    required this.textTheme,
  });

  final FoodStoreDetail store;
  final List<MerchantMenuCategory> categories;
  final String? busyItemId;
  final TextTheme textTheme;

  @override
  State<_CatalogBody> createState() => _CatalogBodyState();
}

enum _ProductFilter { all, onSale, hidden }

class _CatalogBodyState extends State<_CatalogBody> {
  final _search = TextEditingController();
  _ProductFilter _filter = _ProductFilter.all;
  String? _selectedCategoryId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Map<String, String> get _categoryNames {
    return {
      for (final section in widget.store.menuSections) section.id: section.name,
      for (final cat in widget.categories) cat.id: cat.name,
    };
  }

  List<FoodMenuItem> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return [
      for (final item in widget.store.items)
        if ((_filter == _ProductFilter.all) ||
            (_filter == _ProductFilter.onSale && item.onSale) ||
            (_filter == _ProductFilter.hidden && !item.onSale))
          if (_selectedCategoryId == null ||
              (_selectedCategoryId == '_uncategorized'
                  ? item.menuCategoryId == null
                  : item.menuCategoryId == _selectedCategoryId))
            if (q.isEmpty ||
                item.name.toLowerCase().contains(q) ||
                (item.description?.toLowerCase().contains(q) ?? false))
              item,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final catalog = widget.store.items;
    final available = catalog.where((item) => item.onSale).length;
    final hidden = catalog.length - available;
    final l10n = AppLocalizations.of(context);
    final textTheme = widget.textTheme;
    final filtered = _filtered;
    final catNames = _categoryNames;

    return DealGoRefresh(
      onRefresh: () => context.read<MerchantCatalogCubit>().load(
        merchantAccessToken(context),
      ),
      child: ListView(
        padding: dealGoScrollPadding(context, merchantPagePadding),
        children: [
          DealGoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.store.name,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s4),
                Text(
                  l10n.merchantMenuSummary(available, catalog.length),
                  style: textTheme.bodySmall?.copyWith(
                    color: DealGoColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('merchant-open-categories'),
                    onPressed: () async {
                      await context.push(MerchantRoutes.categories);
                      if (context.mounted) {
                        await context.read<MerchantCatalogCubit>().load(
                          merchantAccessToken(context),
                        );
                      }
                    },
                    icon: const Icon(DealGoIcons.list, size: 18),
                    label: Text(l10n.merchantProductsCategories),
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('merchant-open-history'),
                    onPressed: () => context.push(MerchantRoutes.history),
                    icon: const Icon(DealGoIcons.history, size: 18),
                    label: Text(l10n.merchantProductsHistory),
                  ),
                ),
              ],
            ),
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
              () => _filter = _ProductFilter.values.firstWhere(
                (e) => e.name == id,
              ),
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
          if (catNames.isNotEmpty) ...[
            const SizedBox(height: DealGoSpacing.s12),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: DealGoSpacing.s8),
                    child: ChoiceChip(
                      label: Text(l10n.merchantProductsAllCategories),
                      selected: _selectedCategoryId == null,
                      onSelected: (_) =>
                          setState(() => _selectedCategoryId = null),
                    ),
                  ),
                  for (final entry in catNames.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: DealGoSpacing.s8),
                      child: ChoiceChip(
                        label: Text(capitalizeFirstLetter(entry.value)),
                        selected: _selectedCategoryId == entry.key,
                        onSelected: (_) => setState(
                          () => _selectedCategoryId =
                              _selectedCategoryId == entry.key
                              ? null
                              : entry.key,
                        ),
                      ),
                    ),
                  if (catalog.any((i) => i.menuCategoryId == null))
                    ChoiceChip(
                      label: Text(l10n.merchantItemCategoryNone),
                      selected: _selectedCategoryId == '_uncategorized',
                      onSelected: (_) => setState(
                        () => _selectedCategoryId =
                            _selectedCategoryId == '_uncategorized'
                            ? null
                            : '_uncategorized',
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: DealGoSpacing.s16),
          Row(
            children: [
              Expanded(
                child: Text(l10n.checkoutItems, style: textTheme.titleMedium),
              ),
              Text(
                l10n.merchantProductsCount(filtered.length, catalog.length),
                style: textTheme.bodySmall?.copyWith(
                  color: DealGoColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s12),
          if (filtered.isEmpty)
            DealGoStateView(
              key: const Key('merchant-products-empty'),
              art: DealGoStateArt.noSearch,
              title: catalog.isEmpty
                  ? l10n.merchantProductsEmptyMenu
                  : l10n.merchantProductsEmptyFilter,
              compact: true,
            )
          else
            for (final item in filtered) ...[
              _ProductRow(
                item: item,
                categoryName: item.menuCategoryId != null
                    ? catNames[item.menuCategoryId!]
                    : null,
                busy: widget.busyItemId == item.id,
                enabled: widget.busyItemId == null,
              ),
              const SizedBox(height: DealGoSpacing.s12),
            ],
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.item,
    required this.categoryName,
    required this.busy,
    required this.enabled,
  });

  final FoodMenuItem item;
  final String? categoryName;
  final bool busy;
  final bool enabled;

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDealGoSheet<bool>(
      context: context,
      builder: (sheetContext) {
        final sheetL10n = AppLocalizations.of(sheetContext);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DealGoDimensions.pageGutter,
              DealGoSpacing.s20,
              DealGoDimensions.pageGutter,
              DealGoSpacing.s16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  sheetL10n.merchantItemDeleteConfirmTitle,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: DealGoSpacing.s8),
                Text(
                  sheetL10n.merchantItemDeleteConfirmBody(item.name),
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    color: DealGoColors.textSecondary,
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s16),
                Row(
                  children: [
                    Expanded(
                      child: DealGoSecondaryButton(
                        label: sheetL10n.actionCancel,
                        compact: true,
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                      ),
                    ),
                    const SizedBox(width: DealGoSpacing.s8),
                    Expanded(
                      child: DealGoSecondaryButton(
                        key: Key('merchant-confirm-delete-${item.id}'),
                        label: sheetL10n.merchantItemDeleteAction,
                        compact: true,
                        tone: DealGoSecondaryTone.danger,
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    final deleted = await context.read<MerchantCatalogCubit>().deleteItem(
      accessToken: merchantAccessToken(context),
      itemId: item.id,
    );
    if (deleted && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.merchantItemDeleted)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final primaryUrl = item.imageUrls.isNotEmpty
        ? item.imageUrls.first
        : item.imageUrl;
    final imageUrl = resolveMediaUrl(primaryUrl);
    final photoCount = item.imageUrls.isNotEmpty
        ? item.imageUrls.length
        : (item.imageUrl != null && item.imageUrl!.isNotEmpty ? 1 : 0);

    final fallback = ColoredBox(
      color: DealGoColors.subtlePurple,
      child: SizedBox(
        width: 76,
        height: 76,
        child: Icon(DealGoIcons.restaurant, color: DealGoColors.primary),
      ),
    );

    return DealGoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dish Thumbnail + Badges
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? DealGoNetworkImage(
                              imageUrl,
                              width: 76,
                              height: 76,
                              fit: BoxFit.cover,
                              fallback: fallback,
                            )
                          : fallback,
                    ),
                    if (item.discountPercent > 0)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: DealGoColors.danger,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '-${item.discountPercent}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    if (photoCount > 1)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$photoCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: DealGoSpacing.s12),
              // Dish Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FoodPriceText(
                      key: Key('merchant-product-price-${item.id}'),
                      priceVnd: item.priceVnd,
                      originalPriceVnd: item.originalPriceVnd,
                      size: 14,
                    ),
                    if (item.description != null &&
                        item.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: DealGoColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (categoryName != null && categoryName!.isNotEmpty)
                          _MetaBadge(
                            icon: DealGoIcons.tag,
                            label: capitalizeFirstLetter(categoryName!),
                          ),
                        if (item.prepMinutes != null)
                          _MetaBadge(
                            icon: DealGoIcons.timer,
                            label: l10n.merchantItemPrepMinutesChip(
                              item.prepMinutes!,
                            ),
                          ),
                        if (item.optionGroups.isNotEmpty)
                          _MetaBadge(
                            icon: DealGoIcons.layers,
                            label: l10n.merchantItemOptionsGroupCount(
                              item.optionGroups.length,
                            ),
                          ),
                        if (item.soldCount > 0)
                          _MetaBadge(
                            icon: DealGoIcons.trending,
                            label: l10n.merchantProductsSoldCount(
                              '${item.soldCount}',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DealGoSpacing.s8),
              // Status Chip & Availability Switch
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(DealGoSpacing.s8),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    DealGoChip(
                      label: switch (item.moderation) {
                        FoodItemModeration.pending =>
                          l10n.merchantItemPendingReview,
                        FoodItemModeration.rejected =>
                          l10n.merchantItemRejected,
                        FoodItemModeration.approved =>
                          item.available
                              ? l10n.merchantItemOnSale
                              : l10n.merchantItemSoldOut,
                      },
                      tone: switch (item.moderation) {
                        FoodItemModeration.pending => DealGoChipTone.warning,
                        FoodItemModeration.rejected => DealGoChipTone.danger,
                        FoodItemModeration.approved =>
                          item.available
                              ? DealGoChipTone.success
                              : DealGoChipTone.neutral,
                      },
                    ),
                    Switch(
                      key: Key('merchant-catalog-available-${item.id}'),
                      value: item.onSale,
                      onChanged:
                          enabled &&
                              item.moderation == FoodItemModeration.approved
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
          const Divider(height: DealGoSpacing.s16),
          Wrap(
            spacing: DealGoSpacing.s8,
            runSpacing: DealGoSpacing.s4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
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
                    icon: const Icon(DealGoIcons.edit, size: 16),
                    label: Text(l10n.merchantProductsEdit),
                  ),
                  TextButton.icon(
                    key: Key('merchant-open-variants-${item.id}'),
                    onPressed: enabled
                        ? () async {
                            await context.push(
                              MerchantRoutes.itemVariants(
                                item.id,
                                itemName: item.name,
                              ),
                            );
                            if (context.mounted) {
                              context.read<MerchantCatalogCubit>().load(
                                merchantAccessToken(context),
                              );
                            }
                          }
                        : null,
                    icon: const Icon(DealGoIcons.layers, size: 16),
                    label: Text(l10n.merchantVariantsCta),
                  ),
                ],
              ),
              IconButton(
                key: Key('merchant-delete-item-${item.id}'),
                tooltip: l10n.merchantItemDeleteAction,
                onPressed: enabled ? () => _confirmDelete(context) : null,
                icon: const Icon(
                  DealGoIcons.trash,
                  size: 18,
                  color: DealGoColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: DealGoColors.canvas,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: DealGoColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: DealGoColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: DealGoColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
