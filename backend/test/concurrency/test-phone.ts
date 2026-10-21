import { randomInt } from 'node:crypto';

const issued = new Set<string>();

/**
 * A fresh VN-style mobile number for one test login. The concurrency files run in parallel
 * against one database, so a clock-based serial collided across files and logged two tests
 * into the same user (who could already hold an active order). Random 8 digits plus a
 * per-process set keeps every login a new user.
 */
export function uniqueTestPhone(prefix = '09'): string {
  const digits = 10 - prefix.length;
  for (;;) {
    const phone = `${prefix}${String(randomInt(0, 10 ** digits)).padStart(digits, '0')}`;
    if (!issued.has(phone)) {
      issued.add(phone);
      return phone;
    }
  }
}
