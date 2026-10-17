export const AUTH_METHODS = [
  "PASSKEY",
  "PHONE_SMS",
  "EMAIL_LOGIN_IDENTIFIER",
] as const;

export type AuthMethod = (typeof AUTH_METHODS)[number];

export type AuthMethodRow = {
  method: AuthMethod;
  enabled: boolean;
  updatedAt: string;
  updatedByUserId: string | null;
  /** Display timestamp (vi-VN). */
  updatedAtLabel: string;
};

export type PendingToggle = {
  method: AuthMethod;
  enabled: boolean;
};
