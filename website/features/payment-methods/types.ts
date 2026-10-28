export const PAYMENT_SERVICES = ["BIKE", "CAR", "FOOD"] as const;
export type PaymentService = (typeof PAYMENT_SERVICES)[number];
export type ServiceFlags = Record<PaymentService, boolean>;

export type OpsPaymentMethod = {
  code: string;
  label: string;
  group: "WALLET" | "CARD" | "RECOMMENDED" | "ADD_MORE";
  provider: string | null;
  adapterKind: "REAL" | "STUB" | "NONE";
  requiredEnv: string[];
  configured: boolean;
  services: ServiceFlags;
  sortOrder: number;
  unsupportedReason: string | null;
  availableFor: ServiceFlags;
  locked: boolean;
};

export type OpsPaymentMethodsView = {
  walletEnabled: boolean;
  publicBaseUrlConfigured: boolean;
  methods: OpsPaymentMethod[];
};

export type PaymentMethodDraft = {
  services: ServiceFlags;
  sortOrder: number;
  unsupportedReason: string;
};

export type PaymentMethodPatch = {
  code: string;
  services?: Partial<ServiceFlags>;
  sortOrder?: number;
  unsupportedReason?: string | null;
};
