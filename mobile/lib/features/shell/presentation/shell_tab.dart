import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';

enum ShellTabKind {
  customerHome,
  customerBook,
  customerActivity,
  customerShop,
  account,
  driverHome,
  driverJobs,
  driverEarnings,
  driverNotifications,
  merchantHome,
  merchantOrders,
  merchantProducts,
  merchantStats,
}

class ShellTab {
  const ShellTab({
    required this.path,
    required this.icon,
    required this.selectedIcon,
    required this.kind,
  });

  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final ShellTabKind kind;

  String localizedLabel(AppLocalizations l10n) {
    return switch (kind) {
      ShellTabKind.customerHome => l10n.tabHome,
      ShellTabKind.customerActivity => l10n.tabTrips,
      ShellTabKind.customerShop => l10n.tabShop,
      ShellTabKind.account => l10n.tabAccount,
      ShellTabKind.driverHome => l10n.tabOverview,
      ShellTabKind.driverJobs => l10n.tabJobs,
      ShellTabKind.driverEarnings => l10n.tabEarnings,
      ShellTabKind.driverNotifications => l10n.tabNotifications,
      ShellTabKind.merchantHome => l10n.tabOverview,
      ShellTabKind.merchantOrders => l10n.tabOrders,
      ShellTabKind.merchantProducts => l10n.tabProducts,
      ShellTabKind.merchantStats => l10n.tabStats,
      ShellTabKind.customerBook => l10n.tabBook,
    };
  }
}

const customerShellTabs = <ShellTab>[
  ShellTab(
    path: '/customer',
    icon: DealGoIcons.home,
    selectedIcon: DealGoIcons.home,
    kind: ShellTabKind.customerHome,
  ),
  ShellTab(
    path: '/customer/trips',
    icon: DealGoIcons.pin,
    selectedIcon: DealGoIcons.pinFilled,
    kind: ShellTabKind.customerActivity,
  ),
  ShellTab(
    path: '/customer/book',
    icon: DealGoIcons.motorbike,
    selectedIcon: DealGoIcons.motorbike,
    kind: ShellTabKind.customerBook,
  ),
  ShellTab(
    path: '/customer/shop',
    icon: DealGoIcons.shoppingBag,
    selectedIcon: DealGoIcons.shoppingBag,
    kind: ShellTabKind.customerShop,
  ),
  ShellTab(
    path: '/customer/account',
    icon: DealGoIcons.user,
    selectedIcon: DealGoIcons.userRound,
    kind: ShellTabKind.account,
  ),
];

const merchantShellTabs = <ShellTab>[
  ShellTab(
    path: '/merchant',
    icon: DealGoIcons.home,
    selectedIcon: DealGoIcons.home,
    kind: ShellTabKind.merchantHome,
  ),
  ShellTab(
    path: '/merchant/orders',
    icon: DealGoIcons.receipt,
    selectedIcon: DealGoIcons.receipt,
    kind: ShellTabKind.merchantOrders,
  ),
  ShellTab(
    path: '/merchant/products',
    icon: DealGoIcons.restaurant,
    selectedIcon: DealGoIcons.restaurant,
    kind: ShellTabKind.merchantProducts,
  ),
  ShellTab(
    path: '/merchant/stats',
    icon: DealGoIcons.chartBar,
    selectedIcon: DealGoIcons.chartBar,
    kind: ShellTabKind.merchantStats,
  ),
  ShellTab(
    path: '/merchant/account',
    icon: DealGoIcons.user,
    selectedIcon: DealGoIcons.userRound,
    kind: ShellTabKind.account,
  ),
];

const driverShellTabs = <ShellTab>[
  ShellTab(
    path: '/driver',
    icon: DealGoIcons.home,
    selectedIcon: DealGoIcons.home,
    kind: ShellTabKind.driverHome,
  ),
  ShellTab(
    path: '/driver/jobs',
    icon: DealGoIcons.list,
    selectedIcon: DealGoIcons.list,
    kind: ShellTabKind.driverJobs,
  ),
  ShellTab(
    path: '/driver/earnings',
    icon: DealGoIcons.wallet,
    selectedIcon: DealGoIcons.wallet,
    kind: ShellTabKind.driverEarnings,
  ),
  ShellTab(
    path: '/driver/notifications',
    icon: DealGoIcons.notifications,
    selectedIcon: DealGoIcons.notificationsActive,
    kind: ShellTabKind.driverNotifications,
  ),
  ShellTab(
    path: '/driver/account',
    icon: DealGoIcons.user,
    selectedIcon: DealGoIcons.userRound,
    kind: ShellTabKind.account,
  ),
];
