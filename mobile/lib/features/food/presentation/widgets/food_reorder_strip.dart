import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../activity/domain/entities/history_models.dart';
import '../../../activity/domain/usecases/list_food_history.dart';
import '../../domain/entities/food_money.dart';
import '../../domain/entities/food_models.dart';
import '../../domain/params/get_food_order_params.dart';
import '../../domain/usecases/get_food_order.dart';
import 'food_category_tile.dart';
import 'food_reorder_button.dart';
import 'food_widgets.dart';

/// "Đặt lại đơn quen": the last finished food order, ready to refill the cart.
///
/// Hides when the customer has no finished order and on any load failure; the
/// skeleton keeps the strip's height stable while history and detail load.
class FoodReorderStrip extends StatefulWidget {
  const FoodReorderStrip({super.key});

  @override
  State<FoodReorderStrip> createState() => _FoodReorderStripState();
}

class _FoodReorderStripState extends State<FoodReorderStrip> {
  static const _finishedStatuses = {'COMPLETED', 'DELIVERED'};

  FoodOrderDetail? _order;
  var _loading = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final token = currentAccessToken(context);
    if (token == null) {
      setState(() => _loading = false);
      return;
    }
    final listHistory = context.read<ListFoodHistory>();
    final getOrder = context.read<GetFoodOrder>();
    try {
      final history = await listHistory(token);
      final latest = _latestFinished(history);
      if (latest == null) {
        if (mounted) {
          setState(() => _loading = false);
        }
        return;
      }
      final order = await getOrder(
        GetFoodOrderParams(accessToken: token, orderId: latest.id),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _order = order.storeId != null && order.lines.isNotEmpty
            ? order
            : null;
        _loading = false;
      });
    } on Object {
      if (mounted) {
        setState(() {
          _order = null;
          _loading = false;
        });
      }
    }
  }

  HistoryItem? _latestFinished(List<HistoryItem> history) {
    for (final item in history) {
      if (item.kind == HistoryKind.food &&
          _finishedStatuses.contains(item.status)) {
        return item;
      }
    }
    return null;
  }

  Future<void> _reorder() async {
    final order = _order;
    if (order == null || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await reorderIntoCart(context, order);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _StripSkeleton();
    }
    final order = _order;
    if (order == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final itemCount = order.lines.fold<int>(
      0,
      (sum, line) => sum + line.quantity,
    );
    final storeName = order.storeName?.trim();
    return Padding(
      key: const Key('food-reorder-strip'),
      padding: const EdgeInsets.only(bottom: DealGoSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.foodReorderTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: DealGoSpacing.s12),
          Material(
            color: DealGoColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DealGoRadius.button),
              side: BorderSide(color: DealGoColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(DealGoSpacing.s12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(DealGoRadius.small),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Image.asset(
                        foodStoreCoverImage,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            ColoredBox(
                              color: DealGoColors.amberSurface,
                              child: Icon(
                                DealGoIcons.food,
                                color: DealGoColors.primary,
                              ),
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeName == null || storeName.isEmpty
                              ? l10n.foodReorderTitle
                              : storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.foodReorderStripItems(
                            itemCount,
                            formatVnd(order.totalVnd),
                          ),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: DealGoColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                  DealGoSecondaryButton(
                    key: const Key('food-reorder-strip-action'),
                    label: l10n.actionReorder,
                    enabled: !_busy,
                    compact: true,
                    onPressed: _reorder,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StripSkeleton extends StatelessWidget {
  const _StripSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: DealGoSpacing.s16),
      child: DealGoShimmer(
        child: Row(
          children: [
            DealGoSkeletonBox(width: 56, height: 56, radius: 10),
            SizedBox(width: DealGoSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DealGoSkeletonBox(width: 160, height: 14),
                  SizedBox(height: DealGoSpacing.s8),
                  DealGoSkeletonBox(width: 110, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
