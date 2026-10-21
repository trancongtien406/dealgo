import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/components/dealgo_chip.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/format/short_ref.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/support_ticket.dart';

String supportCategoryLabel(AppLocalizations l10n, SupportCategory category) =>
    switch (category) {
      SupportCategory.ride => l10n.supportCategoryRide,
      SupportCategory.food => l10n.supportCategoryFood,
      SupportCategory.payment => l10n.supportCategoryPayment,
      SupportCategory.account => l10n.supportCategoryAccount,
      SupportCategory.safety => l10n.supportCategorySafety,
      SupportCategory.other => l10n.supportCategoryOther,
    };

IconData supportCategoryIcon(SupportCategory category) => switch (category) {
  SupportCategory.ride => DealGoIcons.car,
  SupportCategory.food => DealGoIcons.restaurant,
  SupportCategory.payment => DealGoIcons.wallet,
  SupportCategory.account => DealGoIcons.user,
  SupportCategory.safety => DealGoIcons.shield,
  SupportCategory.other => DealGoIcons.help,
};

String supportPriorityLabel(AppLocalizations l10n, SupportPriority priority) =>
    switch (priority) {
      SupportPriority.low => l10n.supportPriorityLow,
      SupportPriority.normal => l10n.supportPriorityNormal,
      SupportPriority.high => l10n.supportPriorityHigh,
      SupportPriority.urgent => l10n.supportPriorityUrgent,
    };

/// Chip text/tone: an in-progress ticket whose last message is from support reads "Replied".
({String label, DealGoChipTone tone}) supportStatusChip(
  AppLocalizations l10n,
  SupportTicket ticket,
) {
  return switch (ticket.status) {
    SupportStatus.open => (
      label: l10n.supportStatusOpen,
      tone: DealGoChipTone.brand,
    ),
    SupportStatus.inProgress when ticket.awaitingRequester => (
      label: l10n.supportStatusReplied,
      tone: DealGoChipTone.success,
    ),
    SupportStatus.inProgress => (
      label: l10n.supportStatusInProgress,
      tone: DealGoChipTone.warning,
    ),
    SupportStatus.resolved => (
      label: l10n.supportStatusResolved,
      tone: DealGoChipTone.success,
    ),
    SupportStatus.closed => (
      label: l10n.supportStatusClosed,
      tone: DealGoChipTone.neutral,
    ),
  };
}

String? supportRelatedLabel(AppLocalizations l10n, SupportTicket ticket) {
  final id = ticket.relatedId;
  final type = ticket.relatedType;
  if (id == null || type == null) {
    return null;
  }
  final prefix = type == SupportRelatedType.ride
      ? l10n.supportRelatedRide
      : l10n.supportRelatedFood;
  return '$prefix ${shortRef(id)}';
}

String supportTime(BuildContext context, DateTime time) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final now = DateTime.now();
  final sameDay =
      now.year == time.year && now.month == time.month && now.day == time.day;
  return sameDay
      ? DateFormat('HH:mm', locale).format(time)
      : DateFormat('HH:mm dd/MM/yyyy', locale).format(time);
}

/// App shell → ticket role sent to the backend.
String supportRoleForShell(String shellPath) {
  if (shellPath.startsWith('/driver')) return 'DRIVER';
  if (shellPath.startsWith('/merchant')) return 'MERCHANT';
  return 'CUSTOMER';
}
