/** Nest GET/PATCH /v1/ops/auth-methods item (envelope.data). */
export type NestAuthMethod = {
  method: "PASSKEY" | "PHONE_SMS" | "EMAIL_LOGIN_IDENTIFIER";
  enabled: boolean;
  updatedAt: string;
  updatedByUserId: string | null;
};
