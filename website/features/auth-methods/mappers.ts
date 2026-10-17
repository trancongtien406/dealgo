import type { NestAuthMethod } from "@/features/auth-methods/nest-types";
import type { AuthMethod, AuthMethodRow } from "@/features/auth-methods/types";
import { AUTH_METHODS } from "@/features/auth-methods/types";
import { formatOpsDateTime } from "@/lib/ops-time";

const methodLabels: Record<AuthMethod, string> = {
  PASSKEY: "Passkey",
  PHONE_SMS: "SMS điện thoại",
  EMAIL_LOGIN_IDENTIFIER: "Email đã xác minh",
};

const methodHints: Record<AuthMethod, string> = {
  PASSKEY: "Đăng nhập bằng khóa thiết bị (WebAuthn).",
  PHONE_SMS: "Xác minh / đăng nhập qua OTP SMS.",
  EMAIL_LOGIN_IDENTIFIER: "Email đã xác minh dùng làm định danh đăng nhập.",
};

export function authMethodLabel(method: AuthMethod): string {
  return methodLabels[method];
}

export function authMethodHint(method: AuthMethod): string {
  return methodHints[method];
}

export function isAuthMethod(value: string): value is AuthMethod {
  return (AUTH_METHODS as readonly string[]).includes(value);
}

export function mapNestAuthMethod(item: NestAuthMethod): AuthMethodRow {
  return {
    method: item.method,
    enabled: item.enabled,
    updatedAt: item.updatedAt,
    updatedByUserId: item.updatedByUserId,
    updatedAtLabel: formatOpsDateTime(item.updatedAt),
  };
}

/**
 * False when disabling `target` would leave zero enabled methods.
 * Nest refuses that transition outside emergency workflow (FR-OPS-010).
 */
export function canDisableLastMethod(
  methods: ReadonlyArray<Pick<AuthMethodRow, "method" | "enabled">>,
  target: AuthMethod,
): boolean {
  const enabled = methods.filter((row) => row.enabled);
  if (!enabled.some((row) => row.method === target)) {
    return true;
  }
  return enabled.length > 1;
}
