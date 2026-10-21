abstract final class AccountRoutes {
  static String notifications(String shellPath) => '$shellPath/notifications';

  static String addresses(String shellPath) => '$shellPath/addresses';

  static String payments(String shellPath) => '$shellPath/payments';

  static String help(String shellPath) => '$shellPath/help';

  static String deleteAccount(String shellPath) => '$shellPath/delete-account';

  static String editProfile(String shellPath) => '$shellPath/edit-profile';

  static String notificationPrefs(String shellPath) => '$shellPath/notification-prefs';

  static String security(String shellPath) => '$shellPath/security';

  static String sessions(String shellPath) => '$shellPath/sessions';

  static String changePassword(String shellPath) => '$shellPath/change-password';

  static String vouchers(String shellPath) => '$shellPath/vouchers';

  static String supportTickets(String shellPath) => '$shellPath/help/tickets';

  static String supportTicketNew(String shellPath) =>
      '$shellPath/help/tickets/new';

  static String supportTicket(String shellPath, String id) =>
      '$shellPath/help/tickets/${Uri.encodeComponent(id)}';
}
