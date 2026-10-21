import '../../../l10n/app_localizations.dart';
import '../../inbox/domain/entities/inbox_notification.dart';

typedef InboxCopy = ({String title, String body});

/// Localized title/body for status notifications; falls back to the server copy.
InboxCopy inboxCopy(AppLocalizations l10n, InboxNotification item) {
  final status = item.status;
  final InboxCopy? mapped = switch (item.aggregateType) {
    'Ride' => _ride(l10n, status),
    'FoodOrder' => _food(l10n, status),
    'SupportTicket' => (
      title: status == 'RESOLVED'
          ? l10n.inboxSupportResolvedTitle
          : l10n.inboxSupportReplyTitle,
      body: item.body,
    ),
    _ => null,
  };
  return mapped ?? (title: item.title, body: item.body);
}

InboxCopy? _ride(AppLocalizations l10n, String? status) {
  return switch (status) {
    'ASSIGNED' => (
      title: l10n.inboxRideAssignedTitle,
      body: l10n.inboxRideAssignedBody,
    ),
    'DRIVER_EN_ROUTE' => (
      title: l10n.inboxRideDriverEnRouteTitle,
      body: l10n.inboxRideDriverEnRouteBody,
    ),
    'DRIVER_ARRIVED' => (
      title: l10n.inboxRideDriverArrivedTitle,
      body: l10n.inboxRideDriverArrivedBody,
    ),
    'IN_TRIP' => (
      title: l10n.inboxRideInTripTitle,
      body: l10n.inboxRideInTripBody,
    ),
    'COMPLETED' => (
      title: l10n.inboxRideCompletedTitle,
      body: l10n.inboxRideCompletedBody,
    ),
    'CANCELLED' => (
      title: l10n.inboxRideCancelledTitle,
      body: l10n.inboxRideCancelledBody,
    ),
    'EXPIRED' => (
      title: l10n.inboxRideExpiredTitle,
      body: l10n.inboxRideExpiredBody,
    ),
    _ => null,
  };
}

InboxCopy? _food(AppLocalizations l10n, String? status) {
  return switch (status) {
    'PREPARING' => (
      title: l10n.inboxFoodPreparingTitle,
      body: l10n.inboxFoodPreparingBody,
    ),
    'READY' => (title: l10n.inboxFoodReadyTitle, body: l10n.inboxFoodReadyBody),
    'ASSIGNED' => (
      title: l10n.inboxFoodAssignedTitle,
      body: l10n.inboxFoodAssignedBody,
    ),
    'PICKED_UP' => (
      title: l10n.inboxFoodPickedUpTitle,
      body: l10n.inboxFoodPickedUpBody,
    ),
    'DELIVERED' => (
      title: l10n.inboxFoodDeliveredTitle,
      body: l10n.inboxFoodDeliveredBody,
    ),
    'FAILED' => (
      title: l10n.inboxFoodFailedTitle,
      body: l10n.inboxFoodFailedBody,
    ),
    'CANCELLED' => (
      title: l10n.inboxFoodCancelledTitle,
      body: l10n.inboxFoodCancelledBody,
    ),
    _ => null,
  };
}

/// Short relative time for the inbox list.
String inboxWhen(AppLocalizations l10n, DateTime at, DateTime now) {
  final diff = now.difference(at);
  if (diff.inMinutes < 1) {
    return l10n.inboxJustNow;
  }
  if (diff.inHours < 1) {
    return l10n.inboxMinutesAgo(diff.inMinutes);
  }
  final sameDay =
      at.year == now.year && at.month == now.month && at.day == now.day;
  if (sameDay) {
    return l10n.inboxHoursAgo(diff.inHours);
  }
  String two(int value) => value.toString().padLeft(2, '0');
  final yesterday = now.subtract(const Duration(days: 1));
  final isYesterday =
      at.year == yesterday.year &&
      at.month == yesterday.month &&
      at.day == yesterday.day;
  return isYesterday
      ? '${two(at.hour)}:${two(at.minute)}'
      : '${two(at.day)}/${two(at.month)}';
}
