import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

enum ShellTabKind {
  placeholder,
  customerHome,
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
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
    this.kind = ShellTabKind.placeholder,
  });

  /// Fallback VN label; prefer [localizedLabel] at build time.
  final String label;
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
      ShellTabKind.placeholder => path == '/customer/book'
          ? l10n.tabBook
          : label,
    };
  }
}

const customerShellTabs = <ShellTab>[
  ShellTab(
    label: 'Trang chủ',
    path: '/customer',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    kind: ShellTabKind.customerHome,
  ),
  ShellTab(
    label: 'Chuyến đi',
    path: '/customer/trips',
    icon: Icons.route_outlined,
    selectedIcon: Icons.route,
    kind: ShellTabKind.customerActivity,
  ),
  ShellTab(
    label: 'Đặt',
    path: '/customer/book',
    icon: Icons.add_circle_outline,
    selectedIcon: Icons.add_circle,
  ),
  ShellTab(
    label: 'Mua hàng',
    path: '/customer/shop',
    icon: Icons.shopping_bag_outlined,
    selectedIcon: Icons.shopping_bag,
    kind: ShellTabKind.customerShop,
  ),
  ShellTab(
    label: 'Tài khoản',
    path: '/customer/account',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    kind: ShellTabKind.account,
  ),
];

const merchantShellTabs = <ShellTab>[
  ShellTab(
    label: 'Tổng quan',
    path: '/merchant',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    kind: ShellTabKind.merchantHome,
  ),
  ShellTab(
    label: 'Đơn hàng',
    path: '/merchant/orders',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    kind: ShellTabKind.merchantOrders,
  ),
  ShellTab(
    label: 'Sản phẩm',
    path: '/merchant/products',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
    kind: ShellTabKind.merchantProducts,
  ),
  ShellTab(
    label: 'Thống kê',
    path: '/merchant/stats',
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
    kind: ShellTabKind.merchantStats,
  ),
  ShellTab(
    label: 'Tài khoản',
    path: '/merchant/account',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    kind: ShellTabKind.account,
  ),
];

const driverShellTabs = <ShellTab>[
  ShellTab(
    label: 'Tổng quan',
    path: '/driver',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    kind: ShellTabKind.driverHome,
  ),
  ShellTab(
    label: 'Công việc',
    path: '/driver/jobs',
    icon: Icons.work_outline,
    selectedIcon: Icons.work,
    kind: ShellTabKind.driverJobs,
  ),
  ShellTab(
    label: 'Thu nhập',
    path: '/driver/earnings',
    icon: Icons.payments_outlined,
    selectedIcon: Icons.payments,
    kind: ShellTabKind.driverEarnings,
  ),
  ShellTab(
    label: 'Thông báo',
    path: '/driver/notifications',
    icon: Icons.notifications_outlined,
    selectedIcon: Icons.notifications,
    kind: ShellTabKind.driverNotifications,
  ),
  ShellTab(
    label: 'Tài khoản',
    path: '/driver/account',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    kind: ShellTabKind.account,
  ),
];
