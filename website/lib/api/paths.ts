export const apiPaths = {
  opsSession: () => "/api/ops/session",
  opsOverview: () => "/api/ops/overview",
  opsMonitor: () => "/api/ops/monitor",
  opsRides: () => "/api/ops/rides",
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
  opsAuditLogs: () => "/api/ops/audit-logs",
  opsKycQueue: () => "/api/ops/kyc",
  opsExceptions: () => "/api/ops/exceptions",
  opsSettlements: () => "/api/ops/settlements",
  opsAuthMethods: () => "/api/ops/auth-methods",
  opsAuthMethod: (method: string) =>
    `/api/ops/auth-methods/${encodeURIComponent(method)}`,
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
  opsZones: () => "/api/ops/zones",
  opsZonesRules: () => "/api/ops/zones/rules",
  opsRefunds: () => "/api/ops/refunds",
  opsPromotions: () => "/api/ops/promotions",
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
  opsNotificationCmsItem: (id: string) =>
    `/api/ops/notifications/cms/${encodeURIComponent(id)}`,
  opsCatalogCategories: () => "/api/ops/catalog/categories",
  opsCatalogCategoryItem: (code: string) =>
    `/api/ops/catalog/categories/${encodeURIComponent(code)}`,
} as const;

export type ApiPathKey = keyof typeof apiPaths;
