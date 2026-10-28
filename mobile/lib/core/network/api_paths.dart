abstract final class ApiPaths {
  static const authMethods = '/v1/auth/methods';
  static const phoneChallenges = '/v1/auth/phone/challenges';

  static String phoneChallengeVerify(String challengeId) {
    return '/v1/auth/phone/challenges/${Uri.encodeComponent(challengeId)}/verify';
  }

  /// Step 1 of email sign-up: returns a pending OTP challenge, not a session.
  static const emailRegister = '/v1/auth/email/register';

  static String emailRegisterVerify(String challengeId) {
    return '/v1/auth/email/register/${Uri.encodeComponent(challengeId)}/verify';
  }

  static String emailRegisterResend(String challengeId) {
    return '/v1/auth/email/register/${Uri.encodeComponent(challengeId)}/resend';
  }

  static const emailLogin = '/v1/auth/email/login';

  /// DEC-PROD-045 forgot password: emailed 6-digit code, then a new password.
  static const emailPasswordResets = '/v1/auth/email/password-resets';

  static String emailPasswordResetResend(String challengeId) {
    return '/v1/auth/email/password-resets/${Uri.encodeComponent(challengeId)}/resend';
  }

  static String emailPasswordResetConfirm(String challengeId) {
    return '/v1/auth/email/password-resets/${Uri.encodeComponent(challengeId)}/confirm';
  }

  static const passkeyRegistrationOptions =
      '/v1/auth/passkeys/registration/options';
  static const passkeyRegistrationVerify =
      '/v1/auth/passkeys/registration/verify';

  static const sessionsRefresh = '/v1/auth/sessions/refresh';
  static const sessionsRevoke = '/v1/auth/sessions/revoke';

  static const passkeyAuthenticationOptions =
      '/v1/auth/passkeys/authentication/options';
  static const passkeyAuthenticationVerify =
      '/v1/auth/passkeys/authentication/verify';
  static const passkeySignupOptions = '/v1/auth/passkeys/signup/options';
  static const passkeySignupVerify = '/v1/auth/passkeys/signup/verify';

  static const me = '/v1/me';
  static const meAvatar = '/v1/me/avatar';
  static const meNotificationPreferences = '/v1/me/notification-preferences';
  static const meSessions = '/v1/me/sessions';
  static const meSessionsOthers = '/v1/me/sessions/others';
  static const meSessionsCurrent = '/v1/me/sessions/current';
  static const mePassword = '/v1/me/password';

  static String meSession(String id) =>
      '/v1/me/sessions/${Uri.encodeComponent(id)}';

  // Merchant catalog extensions (DEC-PROD-039)
  static const foodMerchantMenuCategories = '/v1/food/merchant/menu-categories';
  static const foodMerchantMenuCategoriesReorder =
      '/v1/food/merchant/menu-categories/reorder';
  static const foodMerchantOrdersHistory = '/v1/food/merchant/orders/history';

  static String foodMerchantMenuCategory(String id) =>
      '/v1/food/merchant/menu-categories/${Uri.encodeComponent(id)}';

  static const partnerApplications = '/v1/me/partner-applications';

  /// DEC-PROD-048: whether KYC/KYB documents are required for [role].
  static String partnerRequirements(String role) {
    return '/v1/me/partner-applications/requirements/${Uri.encodeComponent(role)}';
  }

  static String partnerApplication(String role) {
    return '/v1/me/partner-applications/${Uri.encodeComponent(role)}';
  }

  /// Merchant-owned catalog (owner scoped; creates empty store if none).
  static const foodMerchantCatalog = '/v1/food/merchant/catalog';
  static const foodMerchantStats = '/v1/food/merchant/stats';
  static const foodMerchantStatement = '/v1/food/merchant/statement';

  static const foodMerchantItems = '/v1/food/merchant/items';

  /// M024 busy / pause mode (DEC-PROD-026).
  static const foodMerchantStoreStatus = '/v1/food/merchant/store/status';

  /// M023 weekly hours / closed days / cut-off (DEC-PROD-027).
  static const foodMerchantStoreHours = '/v1/food/merchant/store/hours';

  /// M030 store pickup point.
  static const foodMerchantStoreLocation = '/v1/food/merchant/store/location';

  /// M030 store name / logo (DEC-PROD-045).
  static const foodMerchantStoreProfile = '/v1/food/merchant/store/profile';
  static const foodMerchantStoreLogo = '/v1/food/merchant/store/logo';
  static const foodMerchantStoreCover = '/v1/food/merchant/store/cover';
  static const foodMerchantStoreAcceptSettings =
      '/v1/food/merchant/store/accept-settings';

  static String foodMerchantItemImage(String itemId) =>
      '${foodMerchantItem(itemId)}/image';

  static String foodMerchantItem(String itemId) {
    return '/v1/food/merchant/items/${Uri.encodeComponent(itemId)}';
  }

  static String foodMerchantItemOptions(String itemId) {
    return '/v1/food/merchant/items/${Uri.encodeComponent(itemId)}/options';
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

  static String foodOrderReject(String orderId) {
    return '/v1/food/orders/${Uri.encodeComponent(orderId)}/reject';
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

  /// Driver delivery transitions: `pickup`, `deliver`, `fail`.
  static String foodOrderDeliveryAction(String orderId, String action) {
    return '/v1/food/orders/${Uri.encodeComponent(orderId)}/$action';
  }

  /// Store proposes an edit (POST) — lower quantities / remove lines.
  static String foodOrderChanges(String orderId) {
    return '/v1/food/orders/${Uri.encodeComponent(orderId)}/changes';
  }

  /// Customer answer, `accept` or `reject`.
  static String foodOrderChangeAnswer(
    String orderId,
    String changeId,
    String answer,
  ) {
    return '/v1/food/orders/${Uri.encodeComponent(orderId)}/changes/${Uri.encodeComponent(changeId)}/$answer';
  }

  /// Customer cancel (backend allows PLACED only).
  static String foodOrderCancel(String orderId) {
    return '/v1/food/orders/${Uri.encodeComponent(orderId)}/cancel';
  }

  /// Voucher check before checkout (`POST /v1/promotions/validate`).
  static const promotionsValidate = '/v1/promotions/validate';

  static const rides = '/v1/rides';

  static const ridesOpen = '/v1/rides/open';

  static const rideVehicleClasses = '/v1/rides/vehicle-classes';

  static String ride(String rideId) {
    return '/v1/rides/${Uri.encodeComponent(rideId)}';
  }

  static String rideOffers(String rideId) {
    return '/v1/rides/${Uri.encodeComponent(rideId)}/offers';
  }

  static String rideSelection(String rideId) {
    return '/v1/rides/${Uri.encodeComponent(rideId)}/selection';
  }

  /// Assigned-driver trip transitions: `en-route`, `arrived`, `start`, `complete`.
  static String rideDriverAction(String rideId, String action) {
    return '/v1/rides/${Uri.encodeComponent(rideId)}/$action';
  }

  static String rideCancel(String rideId) {
    return '/v1/rides/${Uri.encodeComponent(rideId)}/cancel';
  }

  /// Negotiation/lifecycle commands.
  static String rideFare(String rideId) =>
      '/v1/rides/${Uri.encodeComponent(rideId)}/fare';
  static String rideOfferDecline(String rideId) =>
      '/v1/rides/${Uri.encodeComponent(rideId)}/offers/decline';
  static String rideOfferWithdraw(String rideId) =>
      '/v1/rides/${Uri.encodeComponent(rideId)}/offers/withdraw';
  static String rideDriverCancel(String rideId) =>
      '/v1/rides/${Uri.encodeComponent(rideId)}/driver-cancel';
  static String rideNoShow(String rideId) =>
      '/v1/rides/${Uri.encodeComponent(rideId)}/no-show';
  static String rideCustomerRating(String rideId) =>
      '/v1/rides/${Uri.encodeComponent(rideId)}/customer-rating';
  static String foodOrderRelease(String orderId) =>
      '/v1/food/orders/${Uri.encodeComponent(orderId)}/release';

  static String rideMessages(String rideId) {
    return '/v1/rides/${Uri.encodeComponent(rideId)}/messages';
  }

  static String foodOrderMessages(String orderId) {
    return '/v1/food/orders/${Uri.encodeComponent(orderId)}/messages';
  }

  /// In-app notification inbox for the signed-in user.
  static const ratings = '/v1/ratings';
  static const storeRatings = '/v1/ratings/stores';
  static String storeReviews(String storeId) =>
      '/v1/ratings/stores/$storeId/reviews';
  static const foodMerchantReviews = '/v1/food/merchant/reviews';
  static String foodMerchantReviewReply(String id) =>
      '/v1/food/merchant/reviews/${Uri.encodeComponent(id)}/reply';
  static const foodMerchantPromotions = '/v1/food/merchant/promotions';
  static String foodMerchantPromotionStatus(String id) =>
      '/v1/food/merchant/promotions/${Uri.encodeComponent(id)}/status';
  static String rating(String subjectType, String subjectId) =>
      '/v1/ratings/$subjectType/$subjectId';
  static const driverHistory = '/v1/driver/history';
  static const driverActiveJob = '/v1/driver/active-job';
  static const customerActiveTrip = '/v1/customer/active-trip';
  static const driverHistorySummary = '/v1/driver/history/summary';
  static const meAddresses = '/v1/me/addresses';

  /// S027 account deletion (DEC-PROD-037).
  static const meAccountDeletion = '/v1/me/account-deletion';
  static String meAccountDeletionConfirm(String id) =>
      '/v1/me/account-deletion/${Uri.encodeComponent(id)}/confirm';
  static const placesSearch = '/v1/places/search';
  static const publicHomeBanners = '/v1/public/home-banners';
  static const publicHomeBannerEvents = '/v1/public/home-banners/events';
  static const publicFoodCategories = '/v1/public/food-categories';
  static const placesReverse = '/v1/places/reverse';
  static const mePlaceHistory = '/v1/me/place-history';
  static String mePlaceHistoryItem(String id) => '/v1/me/place-history/$id';
  static const ridesQuote = '/v1/rides/quote';

  /// Nest road geometry (ROUTING_PROVIDER) for live remaining path / previews.
  static const ridesRoute = '/v1/rides/route';

  static String rideDriver(String rideId) =>
      '/v1/rides/${Uri.encodeComponent(rideId)}/driver';

  /// Customer name for the assigned driver (`GET /v1/rides/:id/customer`).
  static String rideCustomer(String rideId) =>
      '/v1/rides/${Uri.encodeComponent(rideId)}/customer';

  static String foodOrderCustomer(String orderId) =>
      '/v1/food/orders/${Uri.encodeComponent(orderId)}/customer';

  static String rideOfferDriver(String rideId, String offerId) =>
      '/v1/rides/${Uri.encodeComponent(rideId)}/offers/${Uri.encodeComponent(offerId)}/driver';

  static String foodOrderCourier(String orderId) =>
      '/v1/food/orders/${Uri.encodeComponent(orderId)}/courier';
  static const foodQuote = '/v1/food/quote';
  static const supportTickets = '/v1/support/tickets';
  static const helpFaqs = '/v1/public/help/faqs';
  static const promotionsAvailable = '/v1/promotions/available';
  static const publicClientConfig = '/v1/public/client-config';
  static String rideShareLink(String rideId) =>
      '/v1/rides/${Uri.encodeComponent(rideId)}/share-link';
  static String supportTicketAttachment(
    String ticketId,
    String messageId,
    int index,
  ) => '/v1/support/tickets/$ticketId/messages/$messageId/attachments/$index';

  static String supportTicket(String id) =>
      '/v1/support/tickets/${Uri.encodeComponent(id)}';

  static String supportTicketMessages(String id) =>
      '/v1/support/tickets/${Uri.encodeComponent(id)}/messages';
  static String meAddress(String id) => '/v1/me/addresses/$id';
  static const meNotifications = '/v1/me/notifications';
  static const meNotificationsReadAll = '/v1/me/notifications/read-all';
  static String meNotificationRead(String id) {
    return '/v1/me/notifications/${Uri.encodeComponent(id)}/read';
  }

  /// FCM device token registration. Backend may land mid-flight — clients soft-fail.
  static const mePushTokens = '/v1/me/push-tokens';

  /// Driver online/offline presence heartbeat.
  static const mePresence = '/v1/me/presence';

  /// DEC-PROD-031: driver position heartbeat.
  static const mePresenceLocation = '/v1/me/presence/location';

  static String rideDriverLocation(String rideId) {
    return '/v1/rides/${Uri.encodeComponent(rideId)}/driver-location';
  }

  static String foodDriverLocation(String orderId) {
    return '/v1/food/orders/${Uri.encodeComponent(orderId)}/driver-location';
  }

  /// Customer ride history (Nest GET /v1/rides actor-scoped).
  static const meRides = '/v1/rides';

  /// Customer food-order history (Nest GET /v1/food/orders actor-scoped).
  static const meFoodOrders = '/v1/food/orders';

  /// Start an in-app call with the other party of a ride (customer ↔ driver).
  static String rideCalls(String rideId) {
    return '/v1/rides/${Uri.encodeComponent(rideId)}/calls';
  }

  /// Start an in-app call with the other party of a food order.
  static String foodOrderCalls(String orderId) {
    return '/v1/food/orders/${Uri.encodeComponent(orderId)}/calls';
  }

  static const callsConfig = '/v1/calls/config';

  static String call(String callId) {
    return '/v1/calls/${Uri.encodeComponent(callId)}';
  }

  /// `accept`, `decline` or `end`.
  static String callAction(String callId, String action) {
    return '/v1/calls/${Uri.encodeComponent(callId)}/$action';
  }
}
