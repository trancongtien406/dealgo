"use client";

import Link from "next/link";
import { useState, type ReactNode } from "react";
import { OpsIcon, type OpsIconName } from "@/components/ui/ops-icons";
import { toast } from "@/components/ui/toast";
import { countFormat, focusRing, type StatusTone } from "@/lib/admin-format";
import {
  DEFAULT_PAGE_SIZE,
  PAGE_SIZE_OPTIONS,
  type PageSize,
} from "@/lib/admin-pagination";
import { downloadCsv } from "@/lib/download-csv";

export {
  avatarTone,
  countFormat,
  focusRing,
  formatCompactVnd,
  formatCount,
  formatVnd,
  personInitials,
  shareFormat,
  formatShareRatio,
  vnd,
  type StatusTone,
} from "@/lib/admin-format";

export {
  DEFAULT_PAGE_SIZE,
  PAGE_SIZE_OPTIONS,
  type PageSize,
} from "@/lib/admin-pagination";

const iconTone: Record<StatusTone, string> = {
  brand: "bg-brand/10 text-brand",
  food: "bg-food/10 text-food",
  delivery: "bg-delivery/10 text-delivery",
  success: "bg-success/10 text-success",
  danger: "bg-danger/10 text-danger",
};

const chipTone: Record<StatusTone, string> = {
  brand: "bg-brand/10 text-brand",
  food: "bg-food/10 text-food",
  delivery: "bg-delivery/10 text-delivery",
  success: "bg-success/10 text-success",
  danger: "bg-danger/10 text-danger",
};

const noteText: Record<StatusTone, string> = {
  brand: "text-brand",
  food: "text-food",
  delivery: "text-delivery",
  success: "text-success",
  danger: "text-danger",
};

const percentFormat = [
  new Intl.NumberFormat("vi-VN", {
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
    signDisplay: "exceptZero",
  }),
  new Intl.NumberFormat("vi-VN", {
    minimumFractionDigits: 1,
    maximumFractionDigits: 1,
    signDisplay: "exceptZero",
  }),
] as const;

export function AdminBreadcrumb({
  items,
}: {
  items: readonly { label: string; href?: string }[];
}) {
  return (
    <nav aria-label="Đường dẫn">
      <ol className="flex flex-wrap items-center gap-2 text-sm">
        {items.map((item, index) => {
          const last = index === items.length - 1;
          return (
            <li key={item.label} className="flex items-center gap-2">
              {index > 0 ? (
                <span aria-hidden="true" className="text-muted">
                  /
                </span>
              ) : null}
              {last || !item.href ? (
                <span
                  aria-current={last ? "page" : undefined}
                  className={last ? "font-medium text-brand" : "text-muted"}
                >
                  {item.label}
                </span>
              ) : (
                <Link
                  href={item.href}
                  className={`rounded-sm text-muted ${focusRing}`}
                >
                  {item.label}
                </Link>
              )}
            </li>
          );
        })}
      </ol>
    </nav>
  );
}

export function SampleCaption() {
  return null;
}

export function PreviewTabs({
  label,
  tabs,
  current: controlledCurrent,
  onChange,
}: {
  label: string;
  tabs: readonly string[];
  current?: string;
  onChange?: (tab: string) => void;
}) {
  const isControlled = onChange !== undefined;
  const [internalCurrent, setInternalCurrent] = useState(
    () => controlledCurrent ?? tabs[0] ?? "",
  );

  const activeTab =
    isControlled && controlledCurrent !== undefined
      ? controlledCurrent
      : internalCurrent;

  return (
    <div className="min-w-0 overflow-x-auto">
      <div
        role="tablist"
        aria-label={label}
        className="flex w-max min-w-full gap-4 border-b border-border"
      >
        {tabs.map((tab) => {
          const selected = tab === activeTab;
          return (
            <button
              key={tab}
              type="button"
              role="tab"
              aria-selected={selected}
              onClick={() => {
                setInternalCurrent(tab);
                onChange?.(tab);
              }}
              className={
                selected
                  ? `border-b-2 border-brand px-1 pb-2 text-sm font-semibold whitespace-nowrap text-brand cursor-pointer ${focusRing}`
                  : `border-b-2 border-transparent px-1 pb-2 text-sm whitespace-nowrap text-muted hover:text-ink hover:border-border transition-colors cursor-pointer ${focusRing}`
              }
            >
              {tab}
            </button>
          );
        })}
      </div>
    </div>
  );
}

export function QuietChip({ children }: { children: ReactNode }) {
  return (
    <span className="inline-flex items-center whitespace-nowrap rounded-full bg-canvas px-2.5 py-1 text-xs font-semibold text-muted">
      {children}
    </span>
  );
}

export function StatusChip({
  tone,
  dot = false,
  children,
}: {
  tone: StatusTone;
  dot?: boolean;
  children: ReactNode;
}) {
  return (
    <span
      className={`inline-flex items-center whitespace-nowrap rounded-full px-2.5 py-1 text-xs font-semibold ${dot ? "gap-1.5" : ""} ${chipTone[tone]}`}
    >
      {dot ? (
        <span aria-hidden="true" className="size-1.5 rounded-full bg-current" />
      ) : null}
      {children}
    </span>
  );
}

const kpiShell =
  "flex h-full min-h-[8.75rem] min-w-0 flex-col rounded-2xl border bg-white p-4 shadow-sm";

export function KpiCard({
  label,
  value,
  trend,
  digits = 0,
  compare,
  note,
  noteTone,
  icon,
  tone,
  emphasis = false,
}: {
  label: string;
  value: number | string;
  trend?: number;
  digits?: 0 | 1;
  compare?: string;
  note?: string;
  noteTone?: StatusTone;
  icon: OpsIconName;
  tone: StatusTone;
  emphasis?: boolean;
}) {
  const positive = (trend ?? 0) >= 0;
  const footer =
    note !== undefined ? (
      <p
        className={`text-sm leading-5 ${noteTone ? `font-medium ${noteText[noteTone]}` : "text-muted"}`}
      >
        {note}
      </p>
    ) : trend !== undefined && compare !== undefined ? (
      <p className="text-sm leading-5">
        <span
          className={`inline-flex items-center gap-1 font-semibold ${positive ? "text-success" : "text-danger"}`}
        >
          <OpsIcon
            name={positive ? "trend" : "trendDown"}
            className="size-3.5"
          />
          {percentFormat[digits].format(trend)}%
        </span>{" "}
        <span className="text-muted">{compare}</span>
      </p>
    ) : (
      <p
        className="text-sm leading-5 text-transparent select-none"
        aria-hidden="true"
      >
        —
      </p>
    );

  return (
    <article
      className={`${kpiShell} ${
        emphasis ? "border-danger/40 ring-1 ring-danger/10" : "border-border"
      }`}
    >
      <div className="flex items-center gap-3">
        <span
          className={`grid size-11 shrink-0 place-items-center rounded-full ${iconTone[tone]}`}
        >
          <OpsIcon name={icon} className="size-5" />
        </span>
        <p className="min-w-0 text-sm leading-5 font-medium text-muted">
          {label}
        </p>
      </div>
      <p className="mt-3 text-2xl font-bold tracking-tight text-ink tabular-nums sm:text-3xl">
        {typeof value === "number" ? countFormat.format(value) : value}
      </p>
      <div className="mt-auto pt-1">{footer}</div>
    </article>
  );
}

export function TextKpi({
  label,
  value,
  note,
  noteTone,
  icon,
  tone,
}: {
  label: string;
  value: string;
  note: string;
  noteTone?: StatusTone;
  icon: OpsIconName;
  tone: StatusTone;
}) {
  return (
    <article className={`${kpiShell} border-border`}>
      <div className="flex items-center gap-3">
        <span
          className={`grid size-11 shrink-0 place-items-center rounded-full ${iconTone[tone]}`}
        >
          <OpsIcon name={icon} className="size-5" />
        </span>
        <p className="min-w-0 text-sm leading-5 font-medium text-muted">
          {label}
        </p>
      </div>
      <p className="mt-3 text-2xl font-bold tracking-tight break-words text-ink sm:text-3xl">
        {value}
      </p>
      <div className="mt-auto pt-1">
        <p
          className={`text-sm leading-5 ${noteTone ? `font-medium ${noteText[noteTone]}` : "text-muted"}`}
        >
          {note}
        </p>
      </div>
    </article>
  );
}

const ratingFormat = new Intl.NumberFormat("vi-VN", {
  minimumFractionDigits: 1,
  maximumFractionDigits: 1,
});

export function RatingValue({ value }: { value: number | null }) {
  if (value === null) {
    return <span className="text-muted">—</span>;
  }
  return (
    <span className="inline-flex items-center gap-1 font-semibold whitespace-nowrap text-food tabular-nums">
      <OpsIcon name="star" className="size-3.5" />
      {ratingFormat.format(value)}
    </span>
  );
}

export function FilterValue({
  label,
  value,
  icon,
}: {
  label: string;
  value: string;
  icon?: OpsIconName;
}) {
  return (
    <div className="min-w-0">
      <p className="text-xs font-medium text-muted">{label}</p>
      <p className="mt-1.5 flex h-10 min-w-0 items-center gap-2 rounded-xl border border-border bg-white px-3 text-sm text-ink">
        {icon ? (
          <OpsIcon name={icon} className="size-4 shrink-0 text-muted" />
        ) : null}
        <span className="min-w-0 flex-1 truncate">{value}</span>
        <OpsIcon name="chevron" className="size-4 shrink-0 text-muted" />
      </p>
    </div>
  );
}

export function ListSearch({
  id,
  label,
  placeholder,
  value,
  onChange,
  defaultValue,
}: {
  id: string;
  label: string;
  placeholder: string;
  value?: string;
  onChange?: (event: React.ChangeEvent<HTMLInputElement>) => void;
  defaultValue?: string;
}) {
  return (
    <div className="relative min-w-0 flex-1">
      <label htmlFor={id} className="sr-only">
        {label}
      </label>
      <OpsIcon
        name="search"
        className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted"
      />
      <input
        id={id}
        type="search"
        autoComplete="off"
        value={value}
        onChange={onChange}
        defaultValue={defaultValue}
        placeholder={placeholder}
        className={`h-10 w-full rounded-xl border border-border bg-white pr-3 pl-10 text-sm text-ink placeholder:text-muted ${focusRing}`}
      />
    </div>
  );
}

type PreviewTone = "neutral" | "brand" | "ghost" | "danger";

function previewClass(tone: PreviewTone, compact: boolean) {
  const toneClass = {
    neutral: "border-border bg-white text-ink hover:bg-canvas",
    brand: "border-transparent bg-brand text-white hover:bg-brand/90",
    ghost: "border-brand/30 bg-white text-brand hover:bg-brand/10",
    danger: "border-danger/40 bg-white text-danger hover:bg-danger/10",
  }[tone];
  return `inline-flex shrink-0 items-center justify-center gap-2 rounded-xl border font-medium cursor-pointer transition-colors ${compact ? "h-8 px-3 text-xs" : "h-10 px-3 text-sm"} ${toneClass} ${focusRing}`;
}

export function PreviewButton({
  children,
  tone = "neutral",
  compact = false,
  label,
  onClick,
}: {
  children: ReactNode;
  tone?: PreviewTone;
  compact?: boolean;
  label?: string;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      onClick={onClick}
      className={previewClass(tone, compact)}
    >
      {children}
    </button>
  );
}

export function ExportCsvButton({
  filename,
  headers,
  rows,
  tone = "neutral",
  compact = false,
  children,
  emptyMessage = "Không có dữ liệu để xuất.",
}: {
  filename: string;
  headers: readonly string[];
  rows: readonly (readonly string[])[];
  tone?: PreviewTone;
  compact?: boolean;
  children: ReactNode;
  emptyMessage?: string;
}) {
  return (
    <PreviewButton
      tone={tone}
      compact={compact}
      onClick={() => {
        if (rows.length === 0) {
          toast.message(emptyMessage);
          return;
        }
        downloadCsv(filename, headers, rows);
        toast.success("Đã tải CSV.");
      }}
    >
      {children}
    </PreviewButton>
  );
}

export function PreviewLink({
  href,
  children,
  tone = "ghost",
  compact = false,
  label,
}: {
  href: string;
  children: ReactNode;
  tone?: PreviewTone;
  compact?: boolean;
  label?: string;
}) {
  return (
    <Link
      href={href}
      aria-label={label}
      className={previewClass(tone, compact)}
    >
      {children}
    </Link>
  );
}

const iconControlClass = `grid size-9 place-items-center rounded-lg text-brand cursor-pointer hover:bg-canvas transition-colors ${focusRing}`;

export function PreviewIconButton({
  label,
  children,
  onClick,
}: {
  label: string;
  children: ReactNode;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      onClick={onClick}
      className={iconControlClass}
    >
      {children}
    </button>
  );
}

export function PreviewIconLink({
  href,
  label,
  children,
}: {
  href: string;
  label: string;
  children: ReactNode;
}) {
  return (
    <Link href={href} aria-label={label} className={iconControlClass}>
      {children}
    </Link>
  );
}

export function ListPager({
  summary,
  label,
  page = 1,
  lastPage,
  pageSize = DEFAULT_PAGE_SIZE,
  onPageChange,
  onPageSizeChange,
}: {
  summary: string;
  label: string;
  page?: number;
  lastPage: number;
  pageSize?: number;
  onPageChange?: (page: number) => void;
  onPageSizeChange?: (size: PageSize) => void;
}) {
  const totalPages = Math.max(1, lastPage);
  const currentPage = Math.min(Math.max(1, page), totalPages);
  const sizeValue = PAGE_SIZE_OPTIONS.includes(pageSize as PageSize)
    ? (pageSize as PageSize)
    : DEFAULT_PAGE_SIZE;

  // Build dynamic page numbers
  const pageItems: Array<number | "ellipsis"> = [];
  if (totalPages <= 7) {
    for (let i = 1; i <= totalPages; i++) {
      pageItems.push(i);
    }
  } else {
    pageItems.push(1);
    if (currentPage > 4) {
      pageItems.push("ellipsis");
    }
    const start = Math.max(2, currentPage - 1);
    const end = Math.min(totalPages - 1, currentPage + 1);
    for (let i = start; i <= end; i++) {
      pageItems.push(i);
    }
    if (currentPage < totalPages - 3) {
      pageItems.push("ellipsis");
    }
    pageItems.push(totalPages);
  }

  return (
    <div className="flex flex-wrap items-center justify-between gap-3 border-t border-border px-4 py-3 text-sm text-muted">
      <p>{summary}</p>
      <div className="flex flex-wrap items-center gap-3">
        <label className="inline-flex items-center gap-2 text-ink">
          <span className="sr-only">Số dòng mỗi trang</span>
          <select
            value={sizeValue}
            disabled={!onPageSizeChange}
            onChange={(event) => {
              onPageSizeChange?.(Number(event.target.value) as PageSize);
            }}
            className={`h-8 rounded-lg border border-border bg-white px-2 text-sm text-ink cursor-pointer disabled:cursor-not-allowed disabled:opacity-70 ${focusRing}`}
          >
            {PAGE_SIZE_OPTIONS.map((size) => (
              <option key={size} value={size}>
                {countFormat.format(size)}
              </option>
            ))}
          </select>
        </label>
        <nav aria-label={label}>
          <ol className="flex items-center gap-1">
            <li>
              <PagerStep
                label="Trang trước"
                disabled={currentPage <= 1 || !onPageChange}
                onClick={() => onPageChange?.(currentPage - 1)}
              >
                <OpsIcon name="chevron" className="size-4 rotate-90" />
              </PagerStep>
            </li>
            {pageItems.map((item, idx) => {
              if (item === "ellipsis") {
                return (
                  <li
                    key={`ellipsis-${idx}`}
                    aria-hidden="true"
                    className="px-1 text-muted"
                  >
                    …
                  </li>
                );
              }
              const isActive = item === currentPage;
              return (
                <li key={item}>
                  {isActive ? (
                    <span
                      aria-current="page"
                      className="grid size-8 place-items-center rounded-lg bg-brand text-sm font-semibold text-white shadow-xs"
                    >
                      {item}
                    </span>
                  ) : (
                    <PagerStep
                      label={`Trang ${item}`}
                      onClick={() => onPageChange?.(item)}
                    >
                      {item}
                    </PagerStep>
                  )}
                </li>
              );
            })}
            <li>
              <PagerStep
                label="Trang sau"
                disabled={currentPage >= totalPages || !onPageChange}
                onClick={() => onPageChange?.(currentPage + 1)}
              >
                <OpsIcon name="chevron" className="size-4 -rotate-90" />
              </PagerStep>
            </li>
          </ol>
        </nav>
      </div>
    </div>
  );
}

function PagerStep({
  label,
  children,
  disabled = false,
  onClick,
}: {
  label: string;
  children: ReactNode;
  disabled?: boolean;
  onClick?: () => void;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      disabled={disabled}
      onClick={onClick}
      className={`grid h-8 min-w-8 place-items-center rounded-lg px-2 text-sm text-ink transition-colors ${
        disabled
          ? "cursor-not-allowed opacity-40 hover:bg-transparent"
          : "cursor-pointer hover:bg-canvas"
      } ${focusRing}`}
    >
      {children}
    </button>
  );
}

export function Avatar({
  letters,
  tone,
  large = false,
}: {
  letters: string;
  tone: string;
  large?: boolean;
}) {
  return (
    <span
      aria-hidden="true"
      className={`grid shrink-0 place-items-center rounded-full font-semibold ${large ? "size-14 text-base" : "size-9 text-xs"} ${tone}`}
    >
      {letters}
    </span>
  );
}
