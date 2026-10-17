import 'package:flutter/material.dart';

import '../../../core/design_system/components/dealgo_card.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../driver/presentation/pages/driver_earnings_page.dart';
import '../../driver/presentation/pages/driver_home_page.dart';
import '../../driver/presentation/pages/driver_jobs_page.dart';
import '../../driver/presentation/pages/driver_notifications_page.dart';
import '../../food/presentation/pages/food_discovery_page.dart';
import '../../merchant/presentation/pages/merchant_home_page.dart';
import '../../merchant/presentation/pages/merchant_orders_page.dart';
import '../../merchant/presentation/pages/merchant_products_page.dart';
import '../../merchant/presentation/pages/merchant_stats_page.dart';
import '../../ride/presentation/pages/ride_map_page.dart';
import 'account_page.dart';
import 'customer_activity_page.dart';
import 'customer_home_page.dart';
import 'shell_tab.dart';

const _phaseOneEmptyMessage =
    'Giai đoạn 1 chưa có luồng nghiệp vụ. Màn này đang trống.';

class ShellTabPage extends StatelessWidget {
  const ShellTabPage({required this.tab, super.key});

  final ShellTab tab;

  @override
  Widget build(BuildContext context) {
    if (tab.kind == ShellTabKind.customerHome) {
      return const CustomerHomePage();
    }
    if (tab.kind == ShellTabKind.customerActivity) {
      return const CustomerActivityPage();
    }
    if (tab.kind == ShellTabKind.customerShop) {
      return const FoodDiscoveryPage();
    }
    if (tab.path == '/customer/book') {
      return const RideMapPage();
    }
    if (tab.kind == ShellTabKind.driverHome) {
      return const DriverHomePage();
    }
    if (tab.kind == ShellTabKind.driverJobs) {
      return const DriverJobsPage();
    }
    if (tab.kind == ShellTabKind.driverEarnings) {
      return const DriverEarningsPage();
    }
    if (tab.kind == ShellTabKind.driverNotifications) {
      return const DriverNotificationsPage();
    }
    if (tab.kind == ShellTabKind.merchantHome) {
      return const MerchantHomePage();
    }
    if (tab.kind == ShellTabKind.merchantOrders) {
      return const MerchantOrdersPage();
    }
    if (tab.kind == ShellTabKind.merchantProducts) {
      return const MerchantProductsPage();
    }
    if (tab.kind == ShellTabKind.merchantStats) {
      return const MerchantStatsPage();
    }
    if (tab.kind == ShellTabKind.account) {
      return AccountPage(shellPath: tab.path);
    }

    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tab.label, style: textTheme.titleLarge),
            const SizedBox(height: DealGoSpacing.s16),
            const DealGoCard(
              child: Text(
                _phaseOneEmptyMessage,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: DealGoColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
