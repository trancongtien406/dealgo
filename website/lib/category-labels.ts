export const CATEGORY_LABELS: Record<string, string> = {};

export function registerCatalogCategories(
  items: Array<{ code: string; name?: string; displayName?: string }>,
) {
  for (const item of items) {
    if (!item.code) continue;
    const label = item.displayName?.trim() || item.name?.trim();
    if (label) {
      CATEGORY_LABELS[item.code.toLowerCase()] = label;
      CATEGORY_LABELS[item.code] = label;
    }
  }
}

export function catalogCategoryLabel(
  codeOrName: string | null | undefined,
): string {
  if (!codeOrName || !codeOrName.trim()) return "Đang cập nhật";
  const trimmed = codeOrName.trim();
  const key = trimmed.toLowerCase();

  if (CATEGORY_LABELS[key]) {
    return CATEGORY_LABELS[key];
  }
  if (/^khác$/i.test(trimmed)) {
    return "Khác";
  }

  // Fallback: convert kebab-case / snake_case into Title Case
  return trimmed
    .replace(/[_-]+/g, " ")
    .replace(/\b\w/g, (char) => char.toLocaleUpperCase("vi"));
}
