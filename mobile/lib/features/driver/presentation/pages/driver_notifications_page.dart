import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../shell/presentation/notifications_inbox_page.dart';

/// D040 — the driver's real notification inbox (same backend inbox as the
/// customer account; food jobs open the driver job screen).
class DriverNotificationsPage extends StatelessWidget {
  const DriverNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return NotificationsInboxPage(
      shellPath: '/driver/account',
      title: AppLocalizations.of(context).driverNotificationsTitle,
      asTab: true,
    );
  }
}
