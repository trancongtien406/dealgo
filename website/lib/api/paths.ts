export const apiPaths = {
  opsSession: () => "/api/ops/session",
  opsOverview: () => "/api/ops/overview",
  opsReports: () => "/api/ops/reports",
  opsMonitor: () => "/api/ops/monitor",
  opsRides: () => "/api/ops/rides",
  opsChatReview: () => "/api/ops/chat-review",
  opsPublicPages: () => "/api/ops/public-pages",
  opsPublicPage: (slug: string, locale: string) =>
    `/api/ops/public-pages/${encodeURIComponent(slug)}/${encodeURIComponent(locale)}`,

  opsRide: (id: string) => `/api/ops/rides/${encodeURIComponent(id)}`,
  opsRideLedger: (id: string) =>
    `/api/ops/rides/${encodeURIComponent(id)}/ledger`,
  opsRideCancel: (id: string) =>
    `/api/ops/rides/${encodeURIComponent(id)}/cancel`,
  opsRideReassign: (id: string) =>
    `/api/ops/rides/${encodeURIComponent(id)}/reassign`,
  opsFoodOrders: () => "/api/ops/food-orders",
  opsFoodOrder: (id: string) =>
    `/api/ops/food-orders/${encodeURIComponent(id)}`,
  opsFoodOrderLedger: (id: string) =>
    `/api/ops/food-orders/${encodeURIComponent(id)}/ledger`,
  opsFoodOrderCancel: (id: string) =>
    `/api/ops/food-orders/${encodeURIComponent(id)}/cancel`,
  opsFoodOrderReassign: (id: string) =>
    `/api/ops/food-orders/${encodeURIComponent(id)}/reassign`,
  opsPartnerApplications: () => "/api/ops/partner-applications",
  opsPartnerApplication: (id: string) =>
    `/api/ops/partner-applications/${encodeURIComponent(id)}`,
  opsPartnerApplicationApprove: (id: string) =>
    `/api/ops/partner-applications/${encodeURIComponent(id)}/approve`,
  opsPartnerApplicationReject: (id: string) =>
    `/api/ops/partner-applications/${encodeURIComponent(id)}/reject`,
  opsCustomers: () => "/api/ops/customers",
  opsCustomer: (id: string) => `/api/ops/customers/${encodeURIComponent(id)}`,
  opsCustomerActivities: (id: string) =>
    `/api/ops/customers/${encodeURIComponent(id)}/activities`,

  opsDrivers: () => "/api/ops/drivers",
  opsDriver: (id: string) => `/api/ops/drivers/${encodeURIComponent(id)}`,
  opsStores: () => "/api/ops/stores",
  opsStore: (id: string) => `/api/ops/stores/${encodeURIComponent(id)}`,
  opsStoreStatement: (id: string) =>
    `/api/ops/food-stores/${encodeURIComponent(id)}/statement`,
  opsStoreSettlements: (id: string) =>
    `/api/ops/food-stores/${encodeURIComponent(id)}/settlements`,
  opsCatalogModeration: () => "/api/ops/catalog/moderation",
  opsCatalogItemApprove: (id: string) =>
    `/api/ops/catalog/items/${encodeURIComponent(id)}/approve`,
  opsCatalogItemReject: (id: string) =>
    `/api/ops/catalog/items/${encodeURIComponent(id)}/reject`,
  opsTransactions: () => "/api/ops/transactions",
  opsDisputes: () => "/api/ops/disputes",
  opsDispute: (code: string) => `/api/ops/disputes/${encodeURIComponent(code)}`,
  opsDisputeResolve: (code: string) =>
    `/api/ops/disputes/${encodeURIComponent(code)}/resolve`,
  opsSupportTickets: () => "/api/ops/support-tickets",
  opsSupportTicket: (id: string) =>
    `/api/ops/support-tickets/${encodeURIComponent(id)}`,
  opsSupportTicketReplies: (id: string) =>
    `/api/ops/support-tickets/${encodeURIComponent(id)}/replies`,
  opsAuditLogs: () => "/api/ops/audit-logs",
  opsExceptions: () => "/api/ops/exceptions",
  opsSettlements: () => "/api/ops/settlements",
  opsAuthMethods: () => "/api/ops/auth-methods",
  opsAuthMethod: (method: string) =>
    `/api/ops/auth-methods/${encodeURIComponent(method)}`,
  opsHomeBanners: () => "/api/ops/home-banners",
  opsHomeBanner: (id: string) =>
    `/api/ops/home-banners/${encodeURIComponent(id)}`,
  opsHomeBannerImage: (id: string) =>
    `/api/ops/home-banners/${encodeURIComponent(id)}/image`,
  opsHomeBannersReorder: () => "/api/ops/home-banners/reorder",
  opsFoodCategories: () => "/api/ops/food-categories",
  opsFoodCategory: (code: string) =>
    `/api/ops/food-categories/${encodeURIComponent(code)}`,
  opsFoodCategoryImage: (code: string) =>
    `/api/ops/food-categories/${encodeURIComponent(code)}/image`,
  opsFoodCategoriesReorder: () => "/api/ops/food-categories/reorder",
  opsRideVehicleClasses: () => "/api/ops/ride-vehicle-classes",
  opsRideVehicleClass: (code: string) =>
    `/api/ops/ride-vehicle-classes/${encodeURIComponent(code)}`,
  opsRideVehicleClassImage: (code: string) =>
    `/api/ops/ride-vehicle-classes/${encodeURIComponent(code)}/image`,
  opsMapsProviders: () => "/api/ops/maps-providers",
  opsPaymentMethods: () => "/api/ops/payment-methods",
  opsSiteConfig: () => "/api/ops/site-config",
  opsPaymentIntents: () => "/api/ops/payment-intents",
  opsPaymentIntent: (id: string) => `/api/ops/payment-intents/${encodeURIComponent(id)}`,
  opsPaymentIntentRefund: (id: string) => `/api/ops/payment-intents/${encodeURIComponent(id)}/refund`,
  opsPaymentIntentsReconcile: () => "/api/ops/payment-intents/reconcile",
  opsEmailSettings: () => "/api/ops/integrations/email",
  opsEmailTest: () => "/api/ops/integrations/email/test",
  opsMapKeys: () => "/api/ops/integrations/maps",
  opsMapKeysTest: () => "/api/ops/integrations/maps/test",
  opsSentrySettings: () => "/api/ops/integrations/sentry",
  opsSentryTest: () => "/api/ops/integrations/sentry/test",
  opsSystemErrors: () => "/api/ops/system-errors/issues",
  opsSystemErrorsCount: () => "/api/ops/system-errors/issues/count",
  opsSystemError: (id: string) => `/api/ops/system-errors/issues/${encodeURIComponent(id)}`,
  opsSystemErrorStatus: (id: string) =>
    `/api/ops/system-errors/issues/${encodeURIComponent(id)}/status`,
  publicClientConfig: () => "/api/public/client-config",
  opsPlatformSettings: () => "/api/ops/platform-settings",
  opsPlatformSetting: (key: string) =>
    `/api/ops/platform-settings/${encodeURIComponent(key)}`,
  opsFaqs: () => "/api/ops/faqs",
  opsFaq: (id: string) => `/api/ops/faqs/${encodeURIComponent(id)}`,
  opsRoleGrants: () => "/api/ops/role-grants",
  opsRoleGrantApprove: (id: string) =>
    `/api/ops/role-grants/${encodeURIComponent(id)}/approve`,
  opsRoleGrantReject: (id: string) =>
    `/api/ops/role-grants/${encodeURIComponent(id)}/reject`,
  opsStaff: () => "/api/ops/staff",
  opsStaffMe: () => "/api/ops/staff/me",
  opsStaffRbacMatrix: () => "/api/ops/staff/rbac-matrix",
  opsStaffPasswordReset: (id: string) =>
    `/api/ops/staff/${encodeURIComponent(id)}/password-reset`,
  opsStaffSuperAdmin: (id: string) =>
    `/api/ops/staff/${encodeURIComponent(id)}/super-admin`,
  opsStaffRole: (id: string) =>
    `/api/ops/staff/${encodeURIComponent(id)}/staff-role`,
  opsUserDeletionCancel: (id: string) =>
    `/api/ops/users/${encodeURIComponent(id)}/account-deletion/cancel`,
  opsUserFeeBalance: (id: string) =>
    `/api/ops/users/${encodeURIComponent(id)}/fee-balance`,
  opsUserDriverBalance: (id: string) =>
    `/api/ops/users/${encodeURIComponent(id)}/driver-balance`,
  opsUserDriverPayment: (id: string) =>
    `/api/ops/users/${encodeURIComponent(id)}/driver-payments`,
  opsUserFeeSettlement: (id: string) =>
    `/api/ops/users/${encodeURIComponent(id)}/fee-settlements`,
  opsZones: () => "/api/ops/zones",
  opsPlacesSearch: () => "/api/ops/places/search",
  opsZonesRules: () => "/api/ops/zones/rules",
  opsRefunds: () => "/api/ops/refunds",
  opsPromotions: () => "/api/ops/promotions",
  opsReviews: () => "/api/ops/reviews",
  opsReviewVisibility: (id: string) =>
    `/api/ops/reviews/${encodeURIComponent(id)}/visibility`,
  opsPromotion: (id: string) => `/api/ops/promotions/${encodeURIComponent(id)}`,
  opsPromotionStatus: (id: string) =>
    `/api/ops/promotions/${encodeURIComponent(id)}/status`,
  opsDeliveries: () => "/api/ops/deliveries",
  opsNotifications: () => "/api/ops/notifications",
  opsNotificationsCms: () => "/api/ops/notifications/cms",
  opsNotificationCampaign: (code: string) =>
    `/api/ops/notifications/${encodeURIComponent(code)}`,
  opsNotificationApprove: (code: string) =>
    `/api/ops/notifications/${encodeURIComponent(code)}/approve`,
  opsNotificationReject: (code: string) =>
    `/api/ops/notifications/${encodeURIComponent(code)}/reject`,
  opsNotificationSubmit: (code: string) =>
    `/api/ops/notifications/${encodeURIComponent(code)}/submit`,
  opsNotificationCancel: (code: string) =>
    `/api/ops/notifications/${encodeURIComponent(code)}/cancel`,
  opsNotificationCmsItem: (id: string) =>
    `/api/ops/notifications/cms/${encodeURIComponent(id)}`,
} as const;

export type ApiPathKey = keyof typeof apiPaths;
