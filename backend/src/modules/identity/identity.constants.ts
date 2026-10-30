export const PHONE_CHALLENGE_TTL_MS = 5 * 60 * 1000;
export const EMAIL_VERIFICATION_TTL_MS = 24 * 60 * 60 * 1000;
export const PASSKEY_CHALLENGE_TTL_MS = 5 * 60 * 1000;
export const MAX_PHONE_ATTEMPTS = 5;
// Email delivery is slower than SMS, so the sign-up code lives longer than the phone OTP.
export const EMAIL_SIGNUP_TTL_MS = 10 * 60 * 1000;
export const EMAIL_SIGNUP_RESEND_COOLDOWN_MS = 60 * 1000;
export const EMAIL_SIGNUP_MAX_SENDS = 5;
export const EMAIL_SIGNUP_MAX_ATTEMPTS = 5;
// Caps challenges per address so the endpoint cannot be used to flood someone's inbox.
export const EMAIL_SIGNUP_MAX_PER_HOUR = 5;

export const IDENTITY_REPOSITORY = Symbol('IDENTITY_REPOSITORY');
export const SMS_SENDER = Symbol('SMS_SENDER');
export const MAIL_SENDER = Symbol('MAIL_SENDER');
export const DRIVER_PRESENCE_REPOSITORY = Symbol('DRIVER_PRESENCE_REPOSITORY');
/** DEC-PROD-071: `{ canDeliverFood(userId) }`, provided by PartnerModule (resolved lazily, no import cycle). */
export const FOOD_ELIGIBILITY = Symbol('FOOD_ELIGIBILITY');

export {
  AUTH_METHOD_POLICY_REPOSITORY,
  AUTH_METHODS,
  isAuthMethodName,
  type AuthMethodName,
} from './auth-method.constants.js';
