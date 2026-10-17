export const PHONE_CHALLENGE_TTL_MS = 5 * 60 * 1000;
export const EMAIL_VERIFICATION_TTL_MS = 24 * 60 * 60 * 1000;
export const PASSKEY_CHALLENGE_TTL_MS = 5 * 60 * 1000;
export const MAX_PHONE_ATTEMPTS = 5;

export const IDENTITY_REPOSITORY = Symbol('IDENTITY_REPOSITORY');
export const SMS_SENDER = Symbol('SMS_SENDER');
export const MAIL_SENDER = Symbol('MAIL_SENDER');
export const DRIVER_PRESENCE_REPOSITORY = Symbol('DRIVER_PRESENCE_REPOSITORY');

export {
  AUTH_METHOD_POLICY_REPOSITORY,
  AUTH_METHODS,
  isAuthMethodName,
  type AuthMethodName,
} from './auth-method.constants.js';
