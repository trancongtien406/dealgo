/**
 * Privacy & PII protection utilities.
 * Ensures sensitive data like phone numbers and emails are masked at the server
 * level before being sent to client browsers or logged.
 */

/**
 * Masks a phone number for display in ops consoles and public interfaces.
 * Examples:
 *   "0901234567" -> "0901 *** 567"
 *   "+84901234567" -> "+8490 *** 567"
 *   null / undefined / "" -> null
 */
export function maskPhone(raw: string | null | undefined): string | null {
  if (!raw || typeof raw !== 'string') {
    return null;
  }
  const trimmed = raw.trim();
  if (!trimmed) {
    return null;
  }
  const digits = trimmed.replace(/\D/g, '');
  if (digits.length < 6) {
    return trimmed;
  }
  const prefix = trimmed.startsWith('+') ? trimmed.slice(0, 5) : trimmed.slice(0, 4);
  const suffix = trimmed.slice(-3);
  return `${prefix} *** ${suffix}`;
}

/**
 * Masks an email address for privacy.
 * Example: "nguyen.van.a@example.com" -> "ng***a@example.com"
 */
export function maskEmail(raw: string | null | undefined): string | null {
  if (!raw || typeof raw !== 'string') {
    return null;
  }
  const trimmed = raw.trim();
  const atIndex = trimmed.indexOf('@');
  if (atIndex <= 1) {
    return trimmed;
  }
  const user = trimmed.slice(0, atIndex);
  const domain = trimmed.slice(atIndex);
  if (user.length <= 2) {
    return `${user.charAt(0)}*${domain}`;
  }
  return `${user.slice(0, 2)}***${user.slice(-1)}${domain}`;
}
