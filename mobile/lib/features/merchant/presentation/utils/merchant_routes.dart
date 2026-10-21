abstract final class MerchantRoutes {
  static String order(String orderId) {
    return '/merchant/orders/${Uri.encodeComponent(orderId)}';
  }

  static const acceptSettings = '/merchant/settings/accept';
  static const hours = '/merchant/settings/hours';
  static const busy = '/merchant/settings/busy';
  static const location = '/merchant/settings/location';

  /// M030 store name + logo (DEC-PROD-045).
  static const profile = '/merchant/settings/profile';

  /// S015 picker inside the merchant shell (merchant-only accounts cannot open `/customer/*`).
  static const locationPick = '/merchant/settings/location/pick';
  static const categories = '/merchant/products/categories';
  static const history = '/merchant/history';

  static String itemEdit(String itemId) =>
      '/merchant/products/${Uri.encodeComponent(itemId)}/edit';

  static String itemVariants(String itemId, {String? itemName}) {
    final base = '/merchant/products/${Uri.encodeComponent(itemId)}/variants';
    if (itemName == null || itemName.isEmpty) {
      return base;
    }
    return '$base?name=${Uri.encodeQueryComponent(itemName)}';
  }
}
