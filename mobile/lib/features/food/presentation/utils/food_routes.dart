abstract final class FoodRoutes {
  static const search = '/customer/food/search';

  /// Food search opened with a query (home search, DEC-PROD-030).
  static String searchFor(String query) =>
      '$search?q=${Uri.encodeQueryComponent(query)}';
  static const category = '/customer/food/category';

  /// Stores in one Admin-managed category; null = every store, nearest first.
  static String categoryOf(String? code) => code == null
      ? category
      : '$category?category=${Uri.encodeQueryComponent(code)}';

  static String store(String storeId) {
    return '/customer/food/stores/${Uri.encodeComponent(storeId)}';
  }

  static String itemOptions({required String storeId, required String itemId}) {
    return '/customer/food/stores/${Uri.encodeComponent(storeId)}/items/${Uri.encodeComponent(itemId)}';
  }

  static const cart = '/customer/food/cart';
  static const checkout = '/customer/food/checkout';
  static const orderSuccess = '/customer/food/order-success';

  static String order(String orderId) {
    return '/customer/food/orders/${Uri.encodeComponent(orderId)}';
  }

  static String invoice(String orderId) {
    return '/customer/food/orders/${Uri.encodeComponent(orderId)}/invoice';
  }

  static String cancel(String orderId) {
    return '/customer/food/orders/${Uri.encodeComponent(orderId)}/cancel';
  }
}
