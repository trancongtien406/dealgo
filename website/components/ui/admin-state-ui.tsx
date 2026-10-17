import type { ReactNode } from "react";
import { OpsIcon, type OpsIconName } from "@/components/ui/ops-icons";
import { focusRing } from "@/components/ui/admin-list-ui";

export function AdminPageSkeleton({
  kpiCount = 4,
  showChart = false,
}: {
  kpiCount?: number;
  showChart?: boolean;
}) {
  return (
    <div className="min-w-0 space-y-5" aria-busy="true" aria-live="polite">
      <span className="sr-only">Đang tải nội dung…</span>
      <div className="h-4 w-48 animate-pulse rounded bg-border/80" />
      <div className="h-9 w-72 max-w-full animate-pulse rounded-lg bg-border/80" />
      <ul
        className={`grid grid-cols-1 gap-3 sm:grid-cols-2 ${
          kpiCount >= 5 ? "xl:grid-cols-5" : "xl:grid-cols-4"
        }`}
      >
        {Array.from({ length: kpiCount }, (_, index) => (
          <li
            key={index}
            className="h-28 animate-pulse rounded-2xl border border-border bg-white shadow-sm"
          >
            <div className="flex gap-3 p-4">
              <span className="size-11 shrink-0 rounded-full bg-canvas" />
              <div className="min-w-0 flex-1 space-y-2 pt-1">
                <div className="h-3 w-24 rounded bg-canvas" />
                <div className="h-7 w-16 rounded bg-canvas" />
              </div>
            </div>
          </li>
        ))}
      </ul>
      {showChart ? (
        <div className="grid gap-4 xl:grid-cols-[minmax(0,1.7fr)_minmax(18rem,1fr)]">
          <div className="h-72 animate-pulse rounded-2xl border border-border bg-white shadow-sm" />
          <div className="h-72 animate-pulse rounded-2xl border border-border bg-white shadow-sm" />
        </div>
      ) : (
        <div className="overflow-hidden rounded-2xl border border-border bg-white shadow-sm">
          <div className="space-y-0 border-b border-border px-4 py-3">
            <div className="h-4 w-40 animate-pulse rounded bg-canvas" />
          </div>
          <ul className="divide-y divide-border">
            {Array.from({ length: 6 }, (_, index) => (
              <li key={index} className="flex items-center gap-3 px-4 py-3">
                <span className="h-4 w-28 animate-pulse rounded bg-canvas" />
                <span className="h-4 w-36 animate-pulse rounded bg-canvas" />
                <span className="ml-auto h-4 w-20 animate-pulse rounded bg-canvas" />
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}

export function AdminEmptyState({
  icon = "search",
  title,
  description,
  action,
}: {
  icon?: OpsIconName;
  title: string;
  description: string;
  action?: ReactNode;
}) {
  return (
    <div
      role="status"
      className="flex flex-col items-center justify-center rounded-2xl border border-dashed border-border bg-white px-6 py-14 text-center shadow-sm"
    >
      <span className="grid size-12 place-items-center rounded-full bg-canvas text-muted">
        <OpsIcon name={icon} className="size-6" />
      </span>
      <h2 className="mt-4 text-base font-semibold text-ink">{title}</h2>
      <p className="mt-1 max-w-md text-sm text-muted">{description}</p>
      {action ? <div className="mt-4">{action}</div> : null}
    </div>
  );
}

export function AdminResetFilterButton({
  onClick,
  label = "Xóa bộ lọc",
}: {
  onClick: () => void;
  label?: string;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`inline-flex h-10 items-center rounded-xl border border-border bg-white px-3 text-sm font-medium text-ink ${focusRing}`}
    >
      {label}
    </button>
  );
}

/** One baseline row for search + selects + date + actions; wraps cleanly on narrow viewports. */
export function AdminFilterToolbar({
  children,
  className = "",
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <div className={`flex flex-wrap items-end gap-3 ${className}`.trim()}>
      {children}
    </div>
  );
}

export function AdminFilterField({
  children,
  className = "",
  grow = false,
}: {
  children: ReactNode;
  className?: string;
  /** Prefer wider search / primary fields. */
  grow?: boolean;
}) {
  return (
    <div
      className={`min-w-[9.5rem] ${grow ? "min-w-[14rem] flex-[1.4]" : "flex-1"} ${className}`.trim()}
    >
      {children}
    </div>
  );
}

export function AdminListErrorBanner({
  message,
  onRetry,
}: {
  message: string;
  onRetry?: () => void;
}) {
  return (
    <p
      className="rounded-xl border border-danger/30 bg-danger/5 px-3 py-2 text-sm text-danger"
      role="alert"
    >
      {message}
      {onRetry ? (
        <>
          {" "}
          <button
            type="button"
            className={`font-medium underline ${focusRing}`}
            onClick={onRetry}
          >
            Thử lại
          </button>
        </>
      ) : null}
    </p>
  );
}

export function AdminForbiddenState({
  title = "Không có quyền truy cập",
  description = "Tài khoản ops hiện tại không được phép xem dữ liệu này.",
  action,
}: {
  title?: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <AdminEmptyState
      icon="lock"
      title={title}
      description={description}
      action={action}
    />
  );
}

/** Row shimmer inside an existing table — keeps thead visible while loading. */
export function AdminTableBodyShimmer({
  columns,
  rows = 8,
}: {
  columns: number;
  rows?: number;
}) {
  const widths = [
    "w-16",
    "w-28",
    "w-20",
    "w-24",
    "w-14",
    "w-20",
    "w-16",
    "w-12",
  ];
  return (
    <>
      {Array.from({ length: rows }, (_, row) => (
        <tr key={row} className="border-t border-border align-middle">
          {Array.from({ length: columns }, (_, col) => (
            <td key={col} className="px-3 py-3">
              <div
                className={`h-4 max-w-full animate-pulse rounded bg-canvas ${widths[col % widths.length]}`}
              />
            </td>
          ))}
        </tr>
      ))}
    </>
  );
}
