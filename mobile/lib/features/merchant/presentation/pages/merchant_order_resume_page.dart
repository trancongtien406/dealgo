import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../domain/params/merchant_order_action_params.dart';
import '../../domain/usecases/get_merchant_order.dart';
import '../cubit/merchant_queue_cubit.dart';
import '../widgets/merchant_widgets.dart';
import 'merchant_order_page.dart';

/// `/merchant/orders/:id` opened from a notification before
/// the order queue was loaded (cold start / app in background). Loads the
/// queue once (or refetches it when the order is not in the cached queue),
/// then shows the order or the "not found" page.
class MerchantOrderResumePage extends StatefulWidget {
  const MerchantOrderResumePage({
    required this.orderId,
    this.accessToken = merchantAccessToken,
    super.key,
  });

  final String orderId;

  /// Session token reader (tests inject one without an AuthCubit).
  final String? Function(BuildContext context) accessToken;

  @override
  State<MerchantOrderResumePage> createState() =>
      _MerchantOrderResumePageState();
}

class _MerchantOrderResumePageState extends State<MerchantOrderResumePage> {
  bool _requested = false;
  FoodOrderDetail? _detail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  void _ensureLoaded() {
    if (!mounted || _requested) {
      return;
    }
    final queue = context.read<MerchantQueueCubit>();
    final inQueue = merchantOrderFrom(queue.state, widget.orderId) != null;
    if (inQueue) {
      return;
    }
    _requested = true;
    final token = widget.accessToken(context);
    queue.setTokenSource(() {
      if (!mounted) return null;
      return widget.accessToken(context);
    });
    unawaited(queue.load(token));
    if (token != null && token.isNotEmpty) {
      unawaited(_loadDetail(token));
    }
  }

  Future<void> _loadDetail(String token) async {
    try {
      final getOrder = context.read<GetMerchantOrder>();
      final detail = await getOrder(
        MerchantOrderActionParams(accessToken: token, orderId: widget.orderId),
      );
      if (mounted) {
        setState(() => _detail = detail);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MerchantQueueCubit, MerchantQueueState>(
      builder: (context, state) {
        final order = merchantOrderFrom(state, widget.orderId);
        if (order != null) {
          return MerchantOrderPage(order: order);
        }
        if (_detail != null) {
          final d = _detail!;
          return MerchantOrderPage(
            order: MerchantQueueOrder(
              id: d.id,
              storeId: d.storeId ?? '',
              status: d.status,
              deliveryFareVnd: d.deliveryFareVnd,
              subtotalVnd: d.subtotalVnd,
              totalVnd: d.totalVnd,
              dropoff: d.dropoff,
              lineCount: d.lines.length,
              createdAt: d.estimatedReadyAt?.toIso8601String() ?? '',
            ),
          );
        }
        if (state is MerchantQueueLoading && _detail == null) {
          return Scaffold(
            body: MerchantPageFrame(
              title: AppLocalizations.of(context).merchantOrderTitle,
              insetBottom: true,
              body: const Padding(
                padding: merchantPagePadding,
                child: DealGoSkeletonList(itemCount: 4),
              ),
            ),
          );
        }
        return const MerchantMissingOrderPage();
      },
    );
  }
}
