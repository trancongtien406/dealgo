import Link from "next/link";
import type { ReactNode } from "react";
import { AdminBreadcrumb, focusRing, vnd } from "@/components/ui/admin-list-ui";
import { OpsIcon, type OpsIconName } from "@/components/ui/ops-icons";
import { LazyRealMapView } from "@/components/ui/lazy-real-map-view";

export function DetailHeader({
  crumbs,
  title,
  subtitle,
  actions,
}: {
  crumbs: readonly { label: string; href?: string }[];
  title: string;
  subtitle?: string;
  actions: ReactNode;
}) {
  return (
    <div className="min-w-0 space-y-4">
      <AdminBreadcrumb items={crumbs} />
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            {title}
          </h1>
          {subtitle ? (
            <p className="mt-1 max-w-3xl text-sm text-muted">{subtitle}</p>
          ) : null}
        </div>
        <div className="flex max-w-full flex-wrap gap-2">{actions}</div>
      </div>
    </div>
  );
}

export function BackToList({ href }: { href: string }) {
  return (
    <Link
      href={href}
      className={`inline-flex h-10 items-center gap-2 rounded-xl border border-border bg-white px-3 text-sm font-medium text-ink hover:bg-canvas transition-colors cursor-pointer ${focusRing}`}
    >
      <OpsIcon name="arrowRight" className="size-4 rotate-180" />
      Quay lại danh sách
    </Link>
  );
}

export function SampleNotFound({
  crumbs,
  heading,
  listHref,
}: {
  crumbs: readonly { label: string; href?: string }[];
  heading: string;
  listHref: string;
}) {
  return (
    <div className="min-w-0 space-y-4">
      <AdminBreadcrumb items={crumbs} />
      <div
        role="status"
        className="flex flex-col items-center justify-center rounded-2xl border border-dashed border-border bg-white px-6 py-14 text-center shadow-sm"
      >
        <h1 className="text-base font-semibold text-ink">{heading}</h1>
        <p className="mt-1 max-w-md text-sm text-muted">
          Không tìm thấy mục này hoặc bạn không có quyền xem.
        </p>
        <div className="mt-4">
          <BackToList href={listHref} />
        </div>
      </div>
    </div>
  );
}

export function TextAction({
  children,
  onClick,
}: {
  children: ReactNode;
  onClick?: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`inline-flex items-center gap-1 rounded-md text-sm font-medium text-brand hover:underline cursor-pointer ${focusRing}`}
    >
      {children}
    </button>
  );
}

export function SummaryStrip({
  columns,
  children,
}: {
  columns: 5 | 6;
  children: ReactNode;
}) {
  const wide = columns === 6 ? "xl:grid-cols-6" : "xl:grid-cols-5";
  return (
    <section
      className={`grid grid-cols-1 gap-px overflow-hidden rounded-2xl border border-border bg-border sm:grid-cols-2 ${wide}`}
    >
      {children}
    </section>
  );
}

export function SummaryCell({
  label,
  hint,
  children,
}: {
  label: string;
  hint?: string;
  children: ReactNode;
}) {
  return (
    <div className="min-w-0 bg-white p-4">
      <p className="text-xs text-muted">{label}</p>
      <div className="mt-1 min-w-0 text-sm font-semibold break-words text-ink">
        {children}
      </div>
      {hint ? <p className="mt-0.5 text-xs text-muted">{hint}</p> : null}
    </div>
  );
}

export function DetailSection({
  id,
  title,
  extra,
  children,
}: {
  id: string;
  title: string;
  extra?: ReactNode;
  children: ReactNode;
}) {
  return (
    <section
      aria-labelledby={id}
      className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm sm:p-5"
    >
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 id={id} className="text-base font-semibold text-ink">
          {title}
        </h2>
        {extra}
      </div>
      <div className="mt-4 min-w-0">{children}</div>
    </section>
  );
}

export function FieldList({
  rows,
}: {
  rows: readonly { label: string; value: ReactNode }[];
}) {
  return (
    <dl className="divide-y divide-border">
      {rows.map((row) => (
        <div
          key={row.label}
          className="grid gap-1 py-3 sm:grid-cols-[10.5rem_minmax(0,1fr)] sm:items-baseline sm:gap-4"
        >
          <dt className="text-sm text-muted">{row.label}</dt>
          <dd className="min-w-0 text-sm font-medium break-words text-ink">
            {row.value}
          </dd>
        </div>
      ))}
    </dl>
  );
}

export function MoneyLines({
  rows,
  totalLabel,
  total,
}: {
  rows: readonly { label: string; amount: number }[];
  totalLabel: string;
  total: number;
}) {
  return (
    <div className="min-w-0">
      <ul className="divide-y divide-border">
        {rows.map((row) => (
          <li
            key={row.label}
            className="flex items-baseline justify-between gap-4 py-2.5 text-sm"
          >
            <span className="min-w-0 text-muted">{row.label}</span>
            <span className="shrink-0 font-medium text-ink tabular-nums">
              {vnd(row.amount)}
            </span>
          </li>
        ))}
      </ul>
      <div className="mt-3 flex flex-wrap items-center justify-between gap-2 rounded-xl bg-brand/10 px-4 py-3 text-sm font-semibold text-brand">
        <span>{totalLabel}</span>
        <span className="text-base tabular-nums">{vnd(total)}</span>
      </div>
    </div>
  );
}

type MilestoneTone = "done" | "current" | "upcoming";

const milestoneDot: Record<MilestoneTone, string> = {
  done: "bg-success",
  current: "bg-brand",
  upcoming: "bg-muted/40",
};

export function MilestoneList({
  items,
}: {
  items: readonly {
    time: string;
    title: string;
    detail: string;
    tone: MilestoneTone;
  }[];
}) {
  return (
    <ol>
      {items.map((item, index) => (
        <li
          key={`${item.time}-${item.title}`}
          className="grid grid-cols-[3.25rem_1rem_minmax(0,1fr)] gap-x-3"
        >
          <time
            className="pt-0.5 text-sm text-muted tabular-nums"
            dateTime={item.time}
          >
            {item.time}
          </time>
          <span className="relative flex justify-center" aria-hidden="true">
            {index < items.length - 1 ? (
              <span className="absolute top-3 bottom-0 w-px bg-border" />
            ) : null}
            <span
              className={`relative z-10 mt-1.5 size-2.5 rounded-full ${milestoneDot[item.tone]}`}
            />
          </span>
          <div className="min-w-0 pb-4">
            <p className="text-sm font-semibold text-ink">{item.title}</p>
            <p className="text-sm text-muted">{item.detail}</p>
          </div>
        </li>
      ))}
    </ol>
  );
}

export type RoutePoint = { lat: number; lng: number };

function isRoutePoint(point: RoutePoint | null | undefined): point is RoutePoint {
  return (
    !!point &&
    Number.isFinite(point.lat) &&
    Number.isFinite(point.lng) &&
    Math.abs(point.lat) <= 90 &&
    Math.abs(point.lng) <= 180
  );
}

/** Rough zoom so both ends fit in the sketch (Web Mercator, ~440px). */
export function routeSketchZoom(from: RoutePoint, to: RoutePoint): number {
  const span = Math.max(Math.abs(from.lat - to.lat), Math.abs(from.lng - to.lng));
  if (span < 0.008) return 15;
  if (span < 0.02) return 14;
  if (span < 0.05) return 13;
  if (span < 0.12) return 12;
  if (span < 0.3) return 11;
  if (span < 0.8) return 9;
  return 7;
}

/**
 * Route map between the order's real points. With one point it shows a single
 * marker; with none it renders an honest empty state instead of a sample route.
 */
export function RouteSketch({
  label,
  start,
  end,
  from,
  to,
  height = 440,
}: {
  label: string;
  start: string;
  end: string;
  from?: RoutePoint | null;
  to?: RoutePoint | null;
  city?: string;
  height?: number | string;
}) {
  const a = isRoutePoint(from) ? from : null;
  const b = isRoutePoint(to) ? to : null;

  if (!a && !b) {
    return (
      <figure
        aria-label={label}
        data-testid="route-sketch-empty"
        className="relative isolate grid min-w-0 place-items-center rounded-xl border border-dashed border-border bg-canvas p-6 text-center text-sm text-muted"
        style={{ height }}
      >
        <span>Chưa có toạ độ để vẽ tuyến.</span>
        <figcaption className="sr-only">{label}</figcaption>
      </figure>
    );
  }

  if (a && b) {
    return (
      <figure aria-label={label} data-testid="route-sketch" className="relative isolate min-w-0">
        <LazyRealMapView
          center={[(a.lat + b.lat) / 2, (a.lng + b.lng) / 2]}
          zoom={routeSketchZoom(a, b)}
          height={height}
          route={[
            [a.lat, a.lng],
            [b.lat, b.lng],
          ]}
          startLabel={start}
          endLabel={end}
          showControls={true}
          showAttribution={true}
        />
        <figcaption className="sr-only">{label}</figcaption>
      </figure>
    );
  }

  const only = (a ?? b) as RoutePoint;
  return (
    <figure aria-label={label} data-testid="route-sketch-point" className="relative isolate min-w-0">
      <LazyRealMapView
        center={[only.lat, only.lng]}
        zoom={15}
        height={height}
        markers={[
          {
            id: a ? "start" : "end",
            lat: only.lat,
            lng: only.lng,
            label: a ? start : end,
            type: a ? "pickup" : "dropoff",
          },
        ]}
        showControls={true}
        showAttribution={true}
      />
      <figcaption className="sr-only">{label}</figcaption>
    </figure>
  );
}

export function RouteStats({
  items,
  className = "",
}: {
  items: readonly { icon: OpsIconName; label: string; value: string }[];
  className?: string;
}) {
  return (
    <ul
      aria-label="Thông số tuyến"
      className={`mt-3 grid grid-cols-1 gap-2.5 sm:grid-cols-3 ${className}`}
    >
      {items.map((item) => (
        <li
          key={item.label}
          className="flex items-center gap-3 rounded-xl border border-border bg-white p-3 shadow-xs"
        >
          <span className="grid size-9 shrink-0 place-items-center rounded-lg bg-brand/10 text-brand">
            <OpsIcon name={item.icon} className="size-4 shrink-0" />
          </span>
          <span className="min-w-0">
            <span className="block text-[11px] font-medium text-muted">
              {item.label}
            </span>
            <span className="block text-sm font-bold text-ink">
              {item.value}
            </span>
          </span>
        </li>
      ))}
    </ul>
  );
}
