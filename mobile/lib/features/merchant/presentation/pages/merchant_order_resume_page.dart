import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
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
    // A queue loaded before the app went to the background misses orders
    // placed since (the store socket is paused), so a push for a brand-new
    // order must refetch instead of showing "not found".
    final stale =
        queue.state is! MerchantQueueLoading &&
        merchantOrderFrom(queue.state, widget.orderId) == null;
    if (queue.state is! MerchantQueueLoading && !stale) {
      return;
    }
    _requested = true;
    queue.setTokenSource(
      () => context.mounted ? widget.accessToken(context) : null,
    );
    unawaited(queue.load(widget.accessToken(context)));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MerchantQueueCubit, MerchantQueueState>(
      builder: (context, state) {
        final order = merchantOrderFrom(state, widget.orderId);
        if (order != null) {
          return MerchantOrderPage(order: order);
        }
        if (state is MerchantQueueLoading) {
          return Scaffold(
            body: MerchantPageFrame(
              title: AppLocalizations.of(context).merchantOrderTitle,
              insetBottom: true,
              body: const Center(child: CircularProgressIndicator()),
            ),
          );
        }
        return const MerchantMissingOrderPage();
      },
    );
  }
}
