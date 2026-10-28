import type { StatusTone } from "@/lib/admin-format";
import type {
  IssuePeriod,
  IssueSort,
  IssueStatusFilter,
} from "@/features/system-errors/types";

/** Project tabs: label → Sentry project slug (null = every configured project). */
export const PROJECT_TABS: ReadonlyArray<{
  label: string;
  project: string | null;
}> = [
  { label: "Tất cả", project: null },
  { label: "Mobile", project: "flutter" },
  { label: "Backend", project: "dealgo-backend" },
  { label: "Web", project: "dealgo-web" },
];

export const PROJECT_LABELS: Record<string, string> = {
  flutter: "Mobile",
  "dealgo-backend": "Backend",
  "dealgo-web": "Web",
};

export const STATUS_OPTIONS: ReadonlyArray<{
  value: IssueStatusFilter;
  label: string;
}> = [
  { value: "unresolved", label: "Chưa xử lý" },
  { value: "resolved", label: "Đã xử lý" },
  { value: "ignored", label: "Bỏ qua" },
  { value: "all", label: "Tất cả trạng thái" },
];

export const PERIOD_OPTIONS: ReadonlyArray<{
  value: IssuePeriod;
  label: string;
}> = [
  { value: "24h", label: "24 giờ" },
  { value: "7d", label: "7 ngày" },
  { value: "14d", label: "14 ngày" },
  { value: "30d", label: "30 ngày" },
  { value: "90d", label: "90 ngày" },
];

export const SORT_OPTIONS: ReadonlyArray<{ value: IssueSort; label: string }> =
  [
    { value: "date", label: "Mới xảy ra" },
    { value: "freq", label: "Nhiều sự kiện" },
    { value: "user", label: "Nhiều người dùng" },
  ];

export const ENVIRONMENT_OPTIONS = [
  { value: "production", label: "production" },
  { value: "staging", label: "staging" },
  { value: "development", label: "development" },
];

export function projectLabel(slug: string): string {
  return PROJECT_LABELS[slug] ?? slug;
}

export function tabForProject(project: string | null): string {
  return PROJECT_TABS.find((t) => t.project === project)?.label ?? "Tất cả";
}

export function projectForTab(label: string): string | null {
  return PROJECT_TABS.find((t) => t.label === label)?.project ?? null;
}

export function issueStatusLabel(status: string): string {
  return STATUS_OPTIONS.find((o) => o.value === status)?.label ?? status;
}

export function issueStatusTone(status: string): StatusTone {
  if (status === "resolved") return "success";
  if (status === "ignored") return "delivery";
  return "danger";
}

export function levelTone(level: string): StatusTone {
  if (level === "fatal" || level === "error") return "danger";
  if (level === "warning") return "food";
  return "brand";
}

/** Nav badge text: hidden at 0/unknown, capped at 99+. */
export function navBadgeLabel(
  count: number | null | undefined,
): string | undefined {
  if (!count || count <= 0) return undefined;
  return count > 99 ? "99+" : String(count);
}

const countFormat = new Intl.NumberFormat("vi-VN");
export function formatIssueCount(n: number): string {
  return countFormat.format(n);
}

/** Polyline points for a sparkline of `values` in a w×h box (flat line when empty/all zero). */
export function sparklinePoints(
  values: readonly number[],
  width: number,
  height: number,
): string {
  if (values.length === 0) return `0,${height} ${width},${height}`;
  const max = Math.max(...values, 1);
  const step = values.length > 1 ? width / (values.length - 1) : width;
  return values
    .map((v, i) => {
      const x = Math.round(i * step * 10) / 10;
      const y = Math.round((height - (v / max) * (height - 1)) * 10) / 10;
      return `${x},${y}`;
    })
    .join(" ");
}

/** "file:line:col" for a stack frame. */
export function frameLocation(frame: {
  file: string | null;
  line: number | null;
  column: number | null;
}): string {
  if (!frame.file) return "—";
  return [frame.file, frame.line, frame.column]
    .filter((p) => p !== null && p !== undefined)
    .join(":");
}
