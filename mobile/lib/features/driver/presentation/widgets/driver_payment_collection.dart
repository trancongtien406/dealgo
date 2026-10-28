import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../payment/data/driver_collection_api.dart';
import '../../../ride/domain/entities/ride_money.dart';
import 'driver_widgets.dart';

/// Payment method + "Đã thanh toán online / Thu tiền mặt X đ" for the
/// assigned driver. Renders nothing until the server answers (or on error).
class DriverPaymentCollection extends StatefulWidget {
  const DriverPaymentCollection({
    required this.entityType,
    required this.entityId,
    required this.accessToken,
    this.loader,
    this.onLoaded,
    super.key,
  });

  final String entityType;
  final String entityId;
  final String? accessToken;
  final DriverCollectionLoader? loader;
  final ValueChanged<DriverCollection>? onLoaded;

  @override
  State<DriverPaymentCollection> createState() =>
      _DriverPaymentCollectionState();
}

class _DriverPaymentCollectionState extends State<DriverPaymentCollection> {
  DriverCollection? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) return;
    try {
      final loader = widget.loader ?? dioDriverCollectionLoader(getIt<Dio>());
      final data = await loader(
        accessToken: token,
        entityType: widget.entityType,
        entityId: widget.entityId,
      );
      if (!mounted) return;
      setState(() => _data = data);
      widget.onLoaded?.call(data);
    } catch (_) {
      // Optional info: the screen keeps its own cash fallback.
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final method = data.methodCode == 'CASH'
        ? l10n.paymentCashLabel
        : paymentMethodBrand(data.methodCode);
    final String status;
    if (data.fullyPaidOnline) {
      status = l10n.driverPaidOnline;
    } else if (data.paidOnlineVnd > 0) {
      status =
          '${l10n.driverPaidOnlineAmount(formatRideVnd(data.paidOnlineVnd))} · '
          '${l10n.driverCashToCollect(formatRideVnd(data.cashToCollectVnd))}';
    } else if (data.onlinePending) {
      status = l10n.driverOnlinePaymentPending;
    } else {
      status = l10n.driverCashToCollect(formatRideVnd(data.cashToCollectVnd));
    }
    return DriverPanel(
      key: const Key('driver-payment-collection'),
      child: Column(
        children: [
          DriverMoneyRow(label: l10n.driverPaymentMethod, value: method),
          DriverMoneyRow(
            key: const Key('driver-payment-collection-status'),
            label: l10n.driverCollect,
            value: status,
            emphasize: true,
          ),
        ],
      ),
    );
  }
}
