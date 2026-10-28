export type FieldSource = "admin" | "env" | "default" | "unset";

export const EMAIL_PROVIDER_CHOICES = ["smtp", "ses", "disabled"] as const;
export type EmailProviderChoice = (typeof EMAIL_PROVIDER_CHOICES)[number];

export const EMAIL_CONFIG_FIELDS = [
  "provider",
  "fromName",
  "fromAddress",
  "smtpHost",
  "smtpPort",
  "smtpUser",
  "smtpSecure",
  "sesRegion",
  "sesConfigurationSet",
  "sesSnsTopicArn",
] as const;
export type EmailConfigField = (typeof EMAIL_CONFIG_FIELDS)[number];

export const EMAIL_SECRET_FIELDS = [
  "smtpPassword",
  "sesAccessKeyId",
  "sesSecretAccessKey",
] as const;
export type EmailSecretField = (typeof EMAIL_SECRET_FIELDS)[number];

/** Nest GET /v1/ops/integrations/email (secrets are never returned, only `*Set`). */
export type EmailSettingsView = {
  canStoreSecrets: boolean;
  secretsUnreadable: boolean;
  providers: readonly string[];
  provider: EmailProviderChoice | "mock";
  fromName: string;
  fromAddress: string;
  smtp: { host: string; port: number; user: string; secure: boolean; passwordSet: boolean };
  ses: {
    region: string;
    configurationSet: string;
    snsTopicArn: string;
    accessKeyIdSet: boolean;
    secretAccessKeySet: boolean;
  };
  sources: Record<EmailConfigField | EmailSecretField, FieldSource>;
  status: { configured: boolean; verified: boolean; testedAt: string | null };
  updatedAt: string | null;
  webhookPath: string;
};

export type EmailDraft = Record<EmailConfigField, string> &
  Record<EmailSecretField, string>;

/** Secret inputs: "" keeps the stored value, null clears it. */
export type EmailSecretEdits = Partial<Record<EmailSecretField, string | null>>;

export type EmailTestResult = { ok: boolean; error: string | null; view: EmailSettingsView };

export const MAP_KEY_FIELDS = [
  "mapboxPublicToken",
  "mapboxServerToken",
  "googleMapsApiKey",
] as const;
export type MapKeyField = (typeof MAP_KEY_FIELDS)[number];

export type MapKeysView = {
  canStoreSecrets: boolean;
  secretsUnreadable: boolean;
  keys: Array<{ field: MapKeyField; set: boolean; source: "admin" | "env" | "unset"; hint: string | null }>;
  testedAt: string | null;
  updatedAt: string | null;
};

export type MapKeyTestResult = { field: MapKeyField; ok: boolean; detail: string };
