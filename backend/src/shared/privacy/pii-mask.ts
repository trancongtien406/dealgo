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

/**
 * Counterpart-safe name for partner screens: given name plus family initial, e.g.
 * "Trần Công Tiến" → "Tiến T." (Vietnamese order: given name is the last word).
 * Single-word names are returned as-is; blank names give null.
 */
export function maskPersonName(raw: string | null | undefined): string | null {
  if (!raw || typeof raw !== 'string') {
    return null;
  }
  const parts = raw.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) {
    return null;
  }
  const given = parts[parts.length - 1]!.slice(0, 40);
  if (parts.length === 1) {
    return given;
  }
  const initial = Array.from(parts[0]!)[0]!.toLocaleUpperCase('vi');
  return `${given} ${initial}.`;
}
