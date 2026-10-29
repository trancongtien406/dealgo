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

/** Vietnamese mobile (03/05/07/08/09 + 8 digits) as +84…, else null. */
export function normalizeVnMobile(input: string): string | null {
  const phone = normalizePhone(input);
  return phone && /^\+84[35789]\d{8}$/.test(phone) ? phone : null;
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
