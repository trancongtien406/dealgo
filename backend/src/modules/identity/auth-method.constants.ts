export const AUTH_METHOD_POLICY_REPOSITORY = Symbol('AUTH_METHOD_POLICY_REPOSITORY');

/** System-wide auth methods managed by ops (DEC-PROD-006). */
export const AUTH_METHODS = ['PASSKEY', 'PHONE_SMS', 'EMAIL_LOGIN_IDENTIFIER'] as const;

export type AuthMethodName = (typeof AUTH_METHODS)[number];

export function isAuthMethodName(value: string): value is AuthMethodName {
  return (AUTH_METHODS as readonly string[]).includes(value);
}
