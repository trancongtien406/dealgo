abstract final class MerchantRoutes {
  static String order(String orderId) {
    return '/merchant/orders/${Uri.encodeComponent(orderId)}';
  }

  static const acceptSettings = '/merchant/settings/accept';
  static const hours = '/merchant/settings/hours';
  static const busy = '/merchant/settings/busy';

  static String itemVariants(String itemId, {String? itemName}) {
    final base =
        '/merchant/products/${Uri.encodeComponent(itemId)}/variants';
    if (itemName == null || itemName.isEmpty) {
      return base;
    }
    return '$base?name=${Uri.encodeQueryComponent(itemName)}';
  }
}
