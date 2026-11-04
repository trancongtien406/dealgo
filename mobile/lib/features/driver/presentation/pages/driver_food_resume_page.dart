import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../food/domain/entities/food_models.dart';
import '../../../food/domain/params/get_food_order_params.dart';
import '../../../food/domain/usecases/get_food_order.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/driver_widgets.dart';
import 'driver_food_page.dart';

/// `/driver/food/:orderId` without a feed entry (relaunch, deep link): loads
/// the order by id and reopens the offer or the claimed delivery.
class DriverFoodResumePage extends StatefulWidget {
  const DriverFoodResumePage({required this.orderId, super.key});

  final String orderId;

  @override
  State<DriverFoodResumePage> createState() => _DriverFoodResumePageState();
}

class _DriverFoodResumePageState extends State<DriverFoodResumePage> {
  FoodOrderDetail? _order;
  var _loading = true;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = driverAccessToken(context);
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final order = await context.read<GetFoodOrder>()(
        GetFoodOrderParams(accessToken: token, orderId: widget.orderId),
      );
      if (mounted) {
        setState(() {
          _order = order;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    if (order != null) {
      final job = readyJobFromOrder(order);
      return switch (order.status) {
        'READY' => DriverFoodDetailPage(job: job),
        'ASSIGNED' || 'PICKED_UP' => DriverFoodDetailPage(
          job: job,
          resumed: ClaimedFoodDelivery(id: order.id, status: order.status),
        ),
        _ => const DriverMissingJobPage(),
      };
    }
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            key: Key('driver-food-resume-loading'),
          ),
        ),
      );
    }
    if (_failed) {
      final l10n = AppLocalizations.of(context);
      return Scaffold(
        body: DriverPageFrame(
          title: l10n.driverRequestTitle,
          insetBottom: true,
          onBack: () => driverBack(context),
          body: Center(
            child: TextButton(
              key: const Key('driver-food-resume-retry'),
              onPressed: _load,
              child: Text(l10n.driverRequestNotFound),
            ),
          ),
        ),
      );
    }
    return const DriverMissingJobPage();
  }
}

/// Feed-shaped job built from the order detail (same fields the page shows).
ReadyFoodJob readyJobFromOrder(FoodOrderDetail order) => ReadyFoodJob(
  id: order.id,
  storeId: '',
  storeName: order.storeName,
  pickup: order.pickup,
  route: order.route,
  approachRoute: order.approachRoute,
  deliveryFareVnd: order.deliveryFareVnd,
  subtotalVnd: order.subtotalVnd,
  totalVnd: order.totalVnd,
  dropoff: order.dropoff,
  lineCount: order.lines.fold<int>(0, (sum, line) => sum + line.quantity),
  note: order.note,
  utensils: order.utensils,
);
