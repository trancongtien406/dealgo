abstract final class ApiPaths {
  static const phoneChallenges = '/v1/auth/phone/challenges';

  static String phoneChallengeVerify(String challengeId) {
    return '/v1/auth/phone/challenges/${Uri.encodeComponent(challengeId)}/verify';
  }

  static const sessionsRefresh = '/v1/auth/sessions/refresh';

  static const me = '/v1/me';

  static const partnerApplications = '/v1/me/partner-applications';

  static String partnerApplication(String role) {
    return '/v1/me/partner-applications/${Uri.encodeComponent(role)}';
  }

  /// Merchant-owned catalog (owner scoped; creates empty store if none).
  static const foodMerchantCatalog = '/v1/food/merchant/catalog';

  static const foodMerchantItems = '/v1/food/merchant/items';

  static String foodMerchantItem(String itemId) {
    return '/v1/food/merchant/items/${Uri.encodeComponent(itemId)}';
  }

  static String foodMerchantItemAvailability(String itemId) {
    return '/v1/food/merchant/items/${Uri.encodeComponent(itemId)}/availability';
  }

  static const foodStores = '/v1/food/stores';

  static String foodStore(String storeId) {
    return '/v1/food/stores/${Uri.encodeComponent(storeId)}';
  }

  static const foodOrders = '/v1/food/orders';

  static const foodOrdersReady = '/v1/food/orders/ready';

  static const foodOrdersQueue = '/v1/food/orders/queue';

  static String foodOrder(String orderId) {
    return '/v1/food/orders/${Uri.encodeComponent(orderId)}';
  }

  static String foodOrderAccept(String orderId) {
    return '/v1/food/orders/${Uri.encodeComponent(orderId)}/accept';
  }

  static String foodOrderReady(String orderId) {
    return '/v1/food/orders/${Uri.encodeComponent(orderId)}/ready';
  }

  static String foodOrderClaim(String orderId) {
    return '/v1/food/orders/${Uri.encodeComponent(orderId)}/claim';
  }

  static const rides = '/v1/rides';

  static const ridesOpen = '/v1/rides/open';

  static String ride(String rideId) {
    return '/v1/rides/${Uri.encodeComponent(rideId)}';
  }

  static String rideOffers(String rideId) {
    return '/v1/rides/${Uri.encodeComponent(rideId)}/offers';
  }

  static String rideSelection(String rideId) {
    return '/v1/rides/${Uri.encodeComponent(rideId)}/selection';
  }

  static String rideCancel(String rideId) {
    return '/v1/rides/${Uri.encodeComponent(rideId)}/cancel';
  }

  static String rideMessages(String rideId) {
    return '/v1/rides/${Uri.encodeComponent(rideId)}/messages';
  }

  static String foodOrderMessages(String orderId) {
    return '/v1/food/orders/${Uri.encodeComponent(orderId)}/messages';
  }

  /// FCM device token registration. Backend may land mid-flight — clients soft-fail.
  static const mePushTokens = '/v1/me/push-tokens';

  /// Driver online/offline presence heartbeat.
  static const mePresence = '/v1/me/presence';

  /// Customer ride history (Nest GET /v1/rides actor-scoped).
  static const meRides = '/v1/rides';

  /// Customer food-order history (Nest GET /v1/food/orders actor-scoped).
  static const meFoodOrders = '/v1/food/orders';

  static String rideVoiceSession(String rideId) {
    return '/v1/rides/${Uri.encodeComponent(rideId)}/voice-session';
  }

  static String foodOrderVoiceSession(String orderId) {
    return '/v1/food/orders/${Uri.encodeComponent(orderId)}/voice-session';
  }
}
