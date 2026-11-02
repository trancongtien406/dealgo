const E164 = /^\+[1-9]\d{7,14}$/;

export function normalizePhone(input: string): string | null {
  const compact = input.trim().replace(/[\s\-().]/g, '');
  if (compact.startsWith('+')) {
    return E164.test(compact) ? compact : null;
  }
  if (/^0\d{9}$/.test(compact)) {
    return `+84${compact.slice(1)}`;
  }
  if (/^84\d{9}$/.test(compact)) {
    return `+${compact}`;
  }
  if (E164.test(`+${compact}`)) {
    return `+${compact}`;
  }
  return null;
}

/** Two digits after +84 assigned to a VN mobile network (national prefix without the leading 0). */
const VN_MOBILE_PREFIXES = new Set([
  '32', '33', '34', '35', '36', '37', '38', '39',
  '52', '55', '56', '58', '59',
  '70', '76', '77', '78', '79',
  '81', '82', '83', '84', '85', '86', '87', '88', '89',
  '90', '91', '92', '93', '94', '96', '97', '98', '99',
]);

/**
 * Vietnamese mobile as +84 and 9 digits, else null.
 * Accepts `0901 234 567`, `901234567`, `84901234567` and `+84 901 234 567`.
 * Landlines and unassigned blocks (030, 071, 080, 095, …) are rejected.
 */
export function normalizeVnMobile(input: string): string | null {
  const digits = input.trim().replace(/\D/g, '');
  let national: string | null = null;
  if (digits.startsWith('84') && digits.length === 11) {
    national = digits.slice(2);
  } else if (digits.startsWith('0') && digits.length === 10) {
    national = digits.slice(1);
  } else if (digits.length === 9) {
    national = digits;
  }
  if (!national || !VN_MOBILE_PREFIXES.has(national.slice(0, 2))) {
    return null;
  }
  return `+84${national}`;
}

export function redactPhone(phone: string): string {
  if (phone.length <= 6) {
    return '***';
  }
  return `${phone.slice(0, 4)}***${phone.slice(-2)}`;
}

export function normalizeEmail(input: string): string {
  return input.trim().toLowerCase();
}
