import type { DateRangeValue } from "@/components/ui/date-picker";

/**
 * Checks whether a raw date string (e.g. ISO string "2026-10-17T..." or "DD/MM" / "DD/MM/YYYY")
 * falls within the selected admin date range [from, to].
 */
export function isDateWithinRange(
  rawDate: string | null | undefined,
  dateRange: DateRangeValue | undefined,
): boolean {
  if (!dateRange?.from && !dateRange?.to) {
    return true;
  }
  if (!rawDate || rawDate === "—") {
    return true;
  }

  // Handle standard ISO date string
  if (rawDate.includes("-")) {
    const itemIso = rawDate.slice(0, 10);
    if (dateRange.from && itemIso < dateRange.from) return false;
    if (dateRange.to && itemIso > dateRange.to) return false;
    return true;
  }

  // Handle DD/MM or DD/MM/YYYY
  const slashMatch = rawDate.match(/(\d{1,2})\/(\d{1,2})(?:\/(\d{4}))?/);
  if (slashMatch) {
    const day = slashMatch[1].padStart(2, "0");
    const month = slashMatch[2].padStart(2, "0");
    const year = slashMatch[3] ?? String(new Date().getFullYear());
    const itemIso = `${year}-${month}-${day}`;

    if (dateRange.from && itemIso < dateRange.from) return false;
    if (dateRange.to && itemIso > dateRange.to) return false;
    return true;
  }

  return true;
}
