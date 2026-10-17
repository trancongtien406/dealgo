/** Server-safe format helpers (no React client boundary). */

export const focusRing =
  "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ink";

export const countFormat = new Intl.NumberFormat("vi-VN");

export type StatusTone = "brand" | "food" | "delivery" | "success" | "danger";

/**
 * Standard Vietnamese Dong currency formatting.
 * Examples: vnd(50000) => "50.000đ", vnd(null) => "—"
 */
export function vnd(amount: number | null | undefined): string {
  if (amount == null || !Number.isFinite(amount)) {
    return "—";
  }
  return `${countFormat.format(Math.round(amount))}đ`;
}

/** Alias for vnd() */
export const formatVnd = vnd;

/**
 * Compact Vietnamese Dong formatting for large figures (M đ, B đ).
 * Examples: formatCompactVnd(12500000) => "12.5M đ", formatCompactVnd(50000) => "50.000đ"
 */
export function formatCompactVnd(amount: number | null | undefined): string {
  if (amount == null || !Number.isFinite(amount)) {
    return "—";
  }
  if (amount >= 1_000_000_000) {
    return `${(amount / 1_000_000_000).toLocaleString("vi-VN", {
      maximumFractionDigits: 1,
    })}B đ`;
  }
  if (amount >= 1_000_000) {
    return `${(amount / 1_000_000).toLocaleString("vi-VN", {
      maximumFractionDigits: 1,
    })}M đ`;
  }
  return vnd(amount);
}

/**
 * Formats count / total numbers with Vietnamese thousands separators.
 * Examples: formatCount(1250) => "1.250", formatCount(0) => "0"
 */
export function formatCount(count: number | null | undefined): string {
  if (count == null || !Number.isFinite(count)) {
    return "0";
  }
  return countFormat.format(count);
}

export const shareFormat = new Intl.NumberFormat("vi-VN", {
  minimumFractionDigits: 1,
  maximumFractionDigits: 1,
});

/**
 * Calculates and formats the share percentage of a given value relative to the total.
 * Example: formatShareRatio(25, 100) => "25,0%"
 */
export function formatShareRatio(value: number, total: number): string {
  if (total <= 0) return "0,0%";
  return `${shareFormat.format((value / total) * 100)}%`;
}

const avatarTones = [
  "bg-brand/10 text-brand",
  "bg-food/10 text-food",
  "bg-delivery/10 text-delivery",
  "bg-success/10 text-success",
] as const;

export function avatarTone(index: number) {
  return avatarTones[index % avatarTones.length];
}

export function personInitials(name: string) {
  const parts = name.trim().split(/\s+/);
  const first = parts[0]?.charAt(0) ?? "";
  const last =
    parts.length > 1 ? (parts[parts.length - 1]?.charAt(0) ?? "") : "";
  return `${first}${last}`.toLocaleUpperCase("vi");
}
