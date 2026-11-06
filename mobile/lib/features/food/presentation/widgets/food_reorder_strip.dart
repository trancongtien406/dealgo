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
import 'food_reorder_button.dart';
import 'food_widgets.dart';

const _coverSize = 56.0;
const _actionPlaceholderWidth = 68.0;
const _actionPlaceholderHeight = 32.0;

/// "Đặt lại đơn quen": the last finished food order, ready to refill the cart.
///
/// Hides when the customer has no finished order and on any load failure; the
/// skeleton keeps the strip's height stable while history and detail load.
class FoodReorderStrip extends StatefulWidget {
  const FoodReorderStrip({this.refreshToken = 0, super.key});

  final int refreshToken;

  @override
  State<FoodReorderStrip> createState() => _FoodReorderStripState();
}

class _FoodReorderStripState extends State<FoodReorderStrip>
    with AutomaticKeepAliveClientMixin<FoodReorderStrip> {
  static const _finishedStatuses = {'COMPLETED', 'DELIVERED'};

  FoodOrderDetail? _order;
  var _loading = true;
  var _busy = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant FoodReorderStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    try {
      final token = currentAccessToken(context);
      final listHistory = context.read<ListFoodHistory>();
      final getOrder = context.read<GetFoodOrder>();
      if (token == null) {
        return;
      }
      final history = await listHistory(token);
      final latest = _latestFinished(history);
      if (latest == null) {
        return;
      }
      final order = await getOrder(
        GetFoodOrderParams(accessToken: token, orderId: latest.id),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _order = order.storeId != null && order.lines.isNotEmpty ? order : null;
      });
    } on Object {
      if (mounted) {
        setState(() => _order = null);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
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
    super.build(context);
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
                    child: Container(
                      width: _coverSize,
                      height: _coverSize,
                      color: DealGoColors.amberSurface,
                      child: const Center(
                        child: Icon(
                          DealGoIcons.food,
                          color: DealGoColors.primary,
                          size: 20,
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
    final l10n = AppLocalizations.of(context);
    return Padding(
      key: const Key('food-reorder-strip-skeleton'),
      padding: const EdgeInsets.only(bottom: DealGoSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonTitle(title: l10n.foodReorderTitle),
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
              child: DealGoShimmer(
                child: Row(
                  children: [
                    const DealGoSkeletonBox(
                      width: _coverSize,
                      height: _coverSize,
                      radius: DealGoRadius.small,
                    ),
                    const SizedBox(width: DealGoSpacing.s12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DealGoSkeletonBox(width: 160, height: 14),
                          SizedBox(height: DealGoSpacing.s8),
                          DealGoSkeletonBox(width: 110, height: 12),
                        ],
                      ),
                    ),
                    const SizedBox(width: DealGoSpacing.s8),
                    const DealGoSkeletonBox(
                      width: _actionPlaceholderWidth,
                      height: _actionPlaceholderHeight,
                      radius: DealGoRadius.button,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reproduces the loaded title row's height without showing its text, so the
/// feed does not shift when the skeleton is replaced by the real strip.
class _SkeletonTitle extends StatelessWidget {
  const _SkeletonTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Visibility(
          visible: false,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: ExcludeSemantics(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        const DealGoShimmer(child: DealGoSkeletonBox(width: 140, height: 18)),
      ],
    );
  }
}
