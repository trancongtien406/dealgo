import 'package:flutter/material.dart';

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

class ShellTabPage extends StatelessWidget {
  const ShellTabPage({required this.tab, super.key});

  final ShellTab tab;

  @override
  Widget build(BuildContext context) {
    return switch (tab.kind) {
      ShellTabKind.customerHome => const CustomerHomePage(),
      ShellTabKind.customerActivity => const CustomerActivityPage(),
      ShellTabKind.customerShop => const FoodDiscoveryPage(),
      ShellTabKind.customerBook => const RideMapPage(),
      ShellTabKind.driverHome => const DriverHomePage(),
      ShellTabKind.driverJobs => const DriverJobsPage(),
      ShellTabKind.driverEarnings => const DriverEarningsPage(),
      ShellTabKind.driverNotifications => const DriverNotificationsPage(),
      ShellTabKind.merchantHome => const MerchantHomePage(),
      ShellTabKind.merchantOrders => const MerchantOrdersPage(),
      ShellTabKind.merchantProducts => const MerchantProductsPage(),
      ShellTabKind.merchantStats => const MerchantStatsPage(),
      ShellTabKind.account => AccountPage(shellPath: tab.path),
    };
  }
}
