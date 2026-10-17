import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_card.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../food/domain/entities/food_money.dart';
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.actionError!)));
        context.read<MerchantCatalogCubit>().clearActionError();
      },
      child: MerchantPageFrame(
        title: 'Thực đơn',
        onBack: () => merchantBack(context),
        body: Builder(
          builder: (context) {
            final state = context.watch<MerchantCatalogCubit>().state;
            return switch (state) {
              MerchantCatalogLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              MerchantCatalogFailed(:final message) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: DealGoSpacing.s12),
                    FilledButton(
                      onPressed: () => context
                          .read<MerchantCatalogCubit>()
                          .load(merchantAccessToken(context)),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
              MerchantCatalogReady(:final store, :final busyItemId) =>
                _CatalogBody(
                  store: store,
                  busyItemId: busyItemId,
                  textTheme: textTheme,
                ),
            };
          },
        ),
      ),
    );
  }
}

class _CatalogBody extends StatelessWidget {
  const _CatalogBody({
    required this.store,
    required this.busyItemId,
    required this.textTheme,
  });

  final FoodStoreDetail store;
  final String? busyItemId;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final catalog = store.items;
    final available = catalog.where((item) => item.available).length;
    final creating = busyItemId == '_create';
    return ListView(
      padding: merchantPagePadding,
      children: [
        DealGoCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.name, style: textTheme.titleMedium),
                    Text(
                      '$available món đang bán · ${catalog.length} món tổng',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: busyItemId != null
                    ? null
                    : () => _showAddItemDialog(context),
                child: creating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Thêm món'),
              ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        Text('Danh sách món', style: textTheme.titleMedium),
        const SizedBox(height: DealGoSpacing.s12),
        for (final item in catalog) ...[
          _ProductRow(
            item: item,
            busy: busyItemId == item.id,
            enabled: busyItemId == null,
          ),
          const SizedBox(height: DealGoSpacing.s12),
        ],
      ],
    );
  }

  Future<void> _showAddItemDialog(BuildContext context) async {
    final cubit = context.read<MerchantCatalogCubit>();
    final token = merchantAccessToken(context);
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Thêm món'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('merchant-catalog-name'),
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tên món'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: DealGoSpacing.s12),
              TextField(
                key: const Key('merchant-catalog-price'),
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Giá (VND)',
                  hintText: '45000',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              key: const Key('merchant-catalog-create'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
    final name = nameController.text;
    final priceText = priceController.text;
    nameController.dispose();
    priceController.dispose();
    if (submitted != true || !context.mounted) {
      return;
    }
    final price = int.tryParse(priceText);
    if (price == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Giá không hợp lệ')));
      return;
    }
    await cubit.createItem(accessToken: token, name: name, priceVnd: price);
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
    return DealGoCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/food_bun_bo_special.png',
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) {
                return const ColoredBox(
                  color: DealGoColors.subtlePurple,
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Icon(Icons.restaurant, color: DealGoColors.primary),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: textTheme.titleMedium),
                Text(formatVnd(item.priceVnd), style: textTheme.bodySmall),
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
                  child: Text(AppLocalizations.of(context).merchantVariantsCta),
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
                Text(
                  item.available ? 'Đang bán' : 'Tạm hết',
                  style: textTheme.labelMedium?.copyWith(
                    color: item.available
                        ? DealGoColors.brandGreen
                        : DealGoColors.textSecondary,
                  ),
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
                ),
              ],
            ),
        ],
      ),
    );
  }
}
