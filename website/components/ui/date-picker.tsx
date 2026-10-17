"use client";

import { useEffect, useId, useMemo, useState, type ReactNode } from "react";
import { focusRing } from "@/components/ui/admin-list-ui";
import { OpsIcon } from "@/components/ui/ops-icons";

export type DateIso = string;

export type DateRangeValue = {
  from: DateIso | null;
  to: DateIso | null;
};

const weekdayLabels = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"] as const;

const displayDate = new Intl.DateTimeFormat("vi-VN", {
  day: "2-digit",
  month: "2-digit",
  year: "numeric",
});

const monthTitle = new Intl.DateTimeFormat("vi-VN", {
  month: "long",
  year: "numeric",
});

export function formatIso(iso: DateIso | null) {
  if (!iso) {
    return "—";
  }
  const parts = parseIso(iso);
  if (!parts) {
    return iso;
  }
  return displayDate.format(new Date(parts.y, parts.m - 1, parts.d));
}

export function parseIso(
  iso: DateIso,
): { y: number; m: number; d: number } | null {
  const [y, m, d] = iso.split("-").map(Number);
  if (!y || !m || !d) {
    return null;
  }
  return { y, m, d };
}

export function toIso(y: number, m: number, d: number): DateIso {
  return `${y}-${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
}

export function todayIso() {
  const now = new Date();
  return toIso(now.getFullYear(), now.getMonth() + 1, now.getDate());
}

export function addDaysIso(iso: DateIso, days: number): DateIso {
  const parts = parseIso(iso);
  if (!parts) {
    return iso;
  }
  const date = new Date(parts.y, parts.m - 1, parts.d);
  date.setDate(date.getDate() + days);
  return toIso(date.getFullYear(), date.getMonth() + 1, date.getDate());
}

export function startOfMonthIso(iso: DateIso): DateIso {
  const parts = parseIso(iso);
  if (!parts) {
    return iso;
  }
  return toIso(parts.y, parts.m, 1);
}

export function shiftMonth(iso: DateIso, delta: number): DateIso {
  const parts = parseIso(iso);
  if (!parts) {
    return iso;
  }
  const date = new Date(parts.y, parts.m - 1 + delta, 1);
  return toIso(date.getFullYear(), date.getMonth() + 1, 1);
}

export function daysInMonth(y: number, m: number) {
  return new Date(y, m, 0).getDate();
}

/** Monday-first offset: Mon=0 … Sun=6 */
export function mondayFirstWeekday(y: number, m: number, d: number) {
  const js = new Date(y, m - 1, d).getDay();
  return js === 0 ? 6 : js - 1;
}

export function compareIso(a: DateIso, b: DateIso) {
  return a.localeCompare(b);
}

function isInRange(day: DateIso, from: DateIso | null, to: DateIso | null) {
  if (!from || !to) {
    return false;
  }
  const lo = from <= to ? from : to;
  const hi = from <= to ? to : from;
  return day >= lo && day <= hi;
}

type CalendarCell = {
  iso: DateIso;
  day: number;
  inMonth: boolean;
};

function buildMonthGrid(monthCursor: DateIso): CalendarCell[] {
  const parts = parseIso(monthCursor);
  if (!parts) {
    return [];
  }
  const { y, m } = parts;
  const total = daysInMonth(y, m);
  const startOffset = mondayFirstWeekday(y, m, 1);
  const cells: CalendarCell[] = [];

  if (startOffset > 0) {
    const prev = new Date(y, m - 2, 1);
    const prevY = prev.getFullYear();
    const prevM = prev.getMonth() + 1;
    const prevTotal = daysInMonth(prevY, prevM);
    for (let i = startOffset - 1; i >= 0; i -= 1) {
      const d = prevTotal - i;
      cells.push({ iso: toIso(prevY, prevM, d), day: d, inMonth: false });
    }
  }

  for (let d = 1; d <= total; d += 1) {
    cells.push({ iso: toIso(y, m, d), day: d, inMonth: true });
  }

  const next = new Date(y, m, 1);
  const nextY = next.getFullYear();
  const nextM = next.getMonth() + 1;
  let nextDay = 1;
  while (cells.length % 7 !== 0 || cells.length < 42) {
    cells.push({
      iso: toIso(nextY, nextM, nextDay),
      day: nextDay,
      inMonth: false,
    });
    nextDay += 1;
    if (cells.length >= 42) {
      break;
    }
  }

  return cells;
}

export function DateDialogShell({
  open,
  titleId,
  title,
  onClose,
  children,
  footer,
}: {
  open: boolean;
  titleId: string;
  title: string;
  onClose: () => void;
  children: ReactNode;
  footer: ReactNode;
}) {
  useEffect(() => {
    if (!open) {
      return;
    }
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        onClose();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [open, onClose]);

  if (!open) {
    return null;
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-ink/40 p-4 sm:items-center"
      role="presentation"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) {
          onClose();
        }
      }}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        className="w-full max-w-md rounded-2xl border border-border bg-white p-4 shadow-lg"
      >
        <div className="flex items-start justify-between gap-3">
          <h2 id={titleId} className="text-base font-semibold text-ink">
            {title}
          </h2>
          <button
            type="button"
            aria-label="Đóng"
            onClick={onClose}
            className={`grid size-8 place-items-center rounded-lg text-muted ${focusRing}`}
          >
            <OpsIcon name="close" className="size-4" />
          </button>
        </div>
        <div className="mt-4">{children}</div>
        <div className="mt-4 flex flex-wrap justify-end gap-2">{footer}</div>
      </div>
    </div>
  );
}

export function MonthCalendar({
  monthCursor,
  onMonthChange,
  selected,
  rangeFrom,
  rangeTo,
  onDaySelect,
  selectingEnd,
}: {
  monthCursor: DateIso;
  onMonthChange: (iso: DateIso) => void;
  selected?: DateIso | null;
  rangeFrom?: DateIso | null;
  rangeTo?: DateIso | null;
  onDaySelect: (iso: DateIso) => void;
  selectingEnd?: boolean;
}) {
  const cells = useMemo(() => buildMonthGrid(monthCursor), [monthCursor]);
  const today = todayIso();
  const title = useMemo(() => {
    const parts = parseIso(monthCursor);
    if (!parts) {
      return monthCursor;
    }
    const raw = monthTitle.format(new Date(parts.y, parts.m - 1, 1));
    return raw.charAt(0).toUpperCase() + raw.slice(1);
  }, [monthCursor]);

  return (
    <div className="rounded-2xl border border-border bg-canvas/40 p-3">
      <div className="flex items-center justify-between gap-2">
        <button
          type="button"
          aria-label="Tháng trước"
          onClick={() => onMonthChange(shiftMonth(monthCursor, -1))}
          className={`grid size-9 place-items-center rounded-xl border border-border bg-white text-ink ${focusRing}`}
        >
          <OpsIcon name="chevron" className="size-4 rotate-90" />
        </button>
        <p className="text-sm font-semibold capitalize text-ink">{title}</p>
        <button
          type="button"
          aria-label="Tháng sau"
          onClick={() => onMonthChange(shiftMonth(monthCursor, 1))}
          className={`grid size-9 place-items-center rounded-xl border border-border bg-white text-ink ${focusRing}`}
        >
          <OpsIcon name="chevron" className="size-4 -rotate-90" />
        </button>
      </div>
      <div className="mt-3 grid grid-cols-7 gap-1">
        {weekdayLabels.map((label) => (
          <div
            key={label}
            className="grid h-8 place-items-center text-[11px] font-semibold text-muted"
          >
            {label}
          </div>
        ))}
        {cells.map((cell) => {
          const isSelected = selected != null && cell.iso === selected;
          const isRangeStart = rangeFrom != null && cell.iso === rangeFrom;
          const isRangeEnd = rangeTo != null && cell.iso === rangeTo;
          const inRange = isInRange(
            cell.iso,
            rangeFrom ?? null,
            rangeTo ?? null,
          );
          const isToday = cell.iso === today;
          const highlight =
            isSelected || isRangeStart || isRangeEnd
              ? "bg-brand text-white shadow-sm"
              : inRange
                ? "bg-brand/15 text-brand"
                : cell.inMonth
                  ? "bg-white text-ink hover:bg-brand/10"
                  : "bg-transparent text-muted/50 hover:bg-white/80";

          return (
            <button
              key={cell.iso}
              type="button"
              disabled={!cell.inMonth && !selectingEnd}
              aria-label={formatIso(cell.iso)}
              aria-pressed={isSelected || isRangeStart || isRangeEnd}
              onClick={() => onDaySelect(cell.iso)}
              className={`relative grid h-9 place-items-center rounded-xl text-sm font-medium transition-colors cursor-pointer ${highlight} ${focusRing} ${!cell.inMonth ? "opacity-60" : ""}`}
            >
              {cell.day}
              {isToday && !isSelected && !isRangeStart && !isRangeEnd ? (
                <span className="absolute bottom-1 size-1 rounded-full bg-brand" />
              ) : null}
            </button>
          );
        })}
      </div>
    </div>
  );
}

function PresetButton({
  children,
  onClick,
}: {
  children: ReactNode;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`inline-flex h-8 items-center rounded-full border border-border bg-white px-3 text-xs font-medium text-ink hover:border-brand/40 hover:text-brand transition-colors cursor-pointer ${focusRing}`}
    >
      {children}
    </button>
  );
}

export function DatePicker({
  label,
  value,
  onChange,
  placeholder = "Chọn ngày",
}: {
  label: string;
  value: DateIso | null;
  onChange: (value: DateIso | null) => void;
  placeholder?: string;
}) {
  const titleId = useId();
  const [open, setOpen] = useState(false);
  const [draft, setDraft] = useState<DateIso | null>(value);
  // Stable SSR seed — real "today" is applied when the dialog opens.
  const [monthCursor, setMonthCursor] = useState(() =>
    startOfMonthIso(value ?? "2000-01-01"),
  );

  const [prevOpen, setPrevOpen] = useState(open);
  if (open !== prevOpen) {
    setPrevOpen(open);
    if (open) {
      setDraft(value);
      setMonthCursor(startOfMonthIso(value ?? todayIso()));
    }
  }

  return (
    <div className="min-w-0">
      <p className="text-xs font-medium text-muted">{label}</p>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className={`mt-1.5 flex h-10 w-full min-w-0 items-center gap-2 rounded-xl border border-border bg-white px-3 text-left text-sm text-ink cursor-pointer hover:border-brand/40 transition-colors ${focusRing}`}
      >
        <OpsIcon name="calendar" className="size-4 shrink-0 text-muted" />
        <span
          className={`min-w-0 flex-1 truncate ${value ? "" : "text-muted"}`}
        >
          {value ? formatIso(value) : placeholder}
        </span>
        <OpsIcon name="chevron" className="size-4 shrink-0 text-muted" />
      </button>
      <input
        type="hidden"
        name={label}
        value={value ?? ""}
        readOnly
        aria-hidden="true"
      />
      <DateDialogShell
        open={open}
        titleId={titleId}
        title={label}
        onClose={() => setOpen(false)}
        footer={
          <>
            <button
              type="button"
              onClick={() => {
                onChange(null);
                setOpen(false);
              }}
              className={`inline-flex h-10 items-center rounded-xl border border-border bg-white px-3 text-sm font-medium text-ink ${focusRing}`}
            >
              Xóa
            </button>
            <button
              type="button"
              onClick={() => {
                onChange(draft);
                setOpen(false);
              }}
              className={`inline-flex h-10 items-center rounded-xl border border-transparent bg-brand px-3 text-sm font-semibold text-white ${focusRing}`}
            >
              Áp dụng
            </button>
          </>
        }
      >
        <div className="mb-3 flex flex-wrap gap-2">
          <PresetButton
            onClick={() => {
              const today = todayIso();
              setDraft(today);
              setMonthCursor(startOfMonthIso(today));
            }}
          >
            Hôm nay
          </PresetButton>
        </div>
        <MonthCalendar
          monthCursor={monthCursor}
          onMonthChange={setMonthCursor}
          selected={draft}
          onDaySelect={(iso) => {
            setDraft(iso);
            setMonthCursor(startOfMonthIso(iso));
          }}
        />
        <p className="mt-3 text-center text-sm text-muted">
          Đã chọn:{" "}
          <span className="font-medium text-ink">
            {draft ? formatIso(draft) : "—"}
          </span>
        </p>
      </DateDialogShell>
    </div>
  );
}

export function DateRangePicker({
  label,
  value,
  onChange,
  placeholder = "Tất cả thời gian",
}: {
  label: string;
  value: DateRangeValue;
  onChange: (value: DateRangeValue) => void;
  placeholder?: string;
}) {
  const titleId = useId();
  const [open, setOpen] = useState(false);
  const [draft, setDraft] = useState<DateRangeValue>(value);
  const [picking, setPicking] = useState<"from" | "to">("from");
  // Stable SSR seed — real "today" is applied when the dialog opens.
  const [monthCursor, setMonthCursor] = useState(() =>
    startOfMonthIso(value.from ?? value.to ?? "2000-01-01"),
  );

  const [prevOpen, setPrevOpen] = useState(open);
  if (open !== prevOpen) {
    setPrevOpen(open);
    if (open) {
      setDraft(value);
      setPicking("from");
      setMonthCursor(startOfMonthIso(value.from ?? value.to ?? todayIso()));
    }
  }

  const summary = useMemo(() => {
    if (!value.from && !value.to) {
      return placeholder;
    }
    if (value.from && value.to && value.from === value.to) {
      return formatIso(value.from);
    }
    return `${formatIso(value.from)} → ${formatIso(value.to)}`;
  }, [placeholder, value.from, value.to]);

  const applyPreset = (from: DateIso, to: DateIso) => {
    setDraft({ from, to });
    setPicking("from");
    setMonthCursor(startOfMonthIso(from));
  };

  const onDaySelect = (iso: DateIso) => {
    if (picking === "from" || !draft.from) {
      setDraft({ from: iso, to: null });
      setPicking("to");
      return;
    }
    if (compareIso(iso, draft.from) < 0) {
      setDraft({ from: iso, to: draft.from });
    } else {
      setDraft({ from: draft.from, to: iso });
    }
    setPicking("from");
  };

  return (
    <div className="min-w-0">
      <p className="text-xs font-medium text-muted">{label}</p>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className={`mt-1.5 flex h-10 w-full min-w-0 items-center gap-2 rounded-xl border border-border bg-white px-3 text-left text-sm text-ink cursor-pointer hover:border-brand/40 transition-colors ${focusRing}`}
      >
        <OpsIcon name="calendar" className="size-4 shrink-0 text-muted" />
        <span
          className={`min-w-0 flex-1 truncate ${!value.from && !value.to ? "text-muted" : ""}`}
        >
          {summary}
        </span>
        <OpsIcon name="chevron" className="size-4 shrink-0 text-muted" />
      </button>
      <DateDialogShell
        open={open}
        titleId={titleId}
        title={label}
        onClose={() => setOpen(false)}
        footer={
          <>
            <button
              type="button"
              onClick={() => {
                onChange({ from: null, to: null });
                setOpen(false);
              }}
              className={`inline-flex h-10 items-center rounded-xl border border-border bg-white px-3 text-sm font-medium text-ink ${focusRing}`}
            >
              Xóa
            </button>
            <button
              type="button"
              onClick={() => {
                let next = draft;
                if (next.from && next.to && next.from > next.to) {
                  next = { from: next.to, to: next.from };
                }
                onChange(next);
                setOpen(false);
              }}
              className={`inline-flex h-10 items-center rounded-xl border border-transparent bg-brand px-3 text-sm font-semibold text-white ${focusRing}`}
            >
              Áp dụng
            </button>
          </>
        }
      >
        <div className="mb-3 flex flex-wrap gap-2">
          <PresetButton
            onClick={() => {
              const today = todayIso();
              applyPreset(today, today);
            }}
          >
            Hôm nay
          </PresetButton>
          <PresetButton
            onClick={() => {
              const to = todayIso();
              applyPreset(addDaysIso(to, -6), to);
            }}
          >
            7 ngày
          </PresetButton>
          <PresetButton
            onClick={() => {
              const to = todayIso();
              const parts = parseIso(to);
              if (!parts) {
                return;
              }
              applyPreset(toIso(parts.y, parts.m, 1), to);
            }}
          >
            Tháng này
          </PresetButton>
        </div>
        <div className="mb-3 grid grid-cols-2 gap-2 text-sm">
          <button
            type="button"
            onClick={() => setPicking("from")}
            className={`rounded-xl border px-3 py-2 text-left ${picking === "from" ? "border-brand bg-brand/5" : "border-border bg-white"} ${focusRing}`}
          >
            <span className="block text-xs text-muted">Từ ngày</span>
            <span className="font-medium text-ink">
              {formatIso(draft.from)}
            </span>
          </button>
          <button
            type="button"
            onClick={() => setPicking("to")}
            className={`rounded-xl border px-3 py-2 text-left ${picking === "to" ? "border-brand bg-brand/5" : "border-border bg-white"} ${focusRing}`}
          >
            <span className="block text-xs text-muted">Đến ngày</span>
            <span className="font-medium text-ink">{formatIso(draft.to)}</span>
          </button>
        </div>
        <MonthCalendar
          monthCursor={monthCursor}
          onMonthChange={setMonthCursor}
          rangeFrom={draft.from}
          rangeTo={draft.to}
          selectingEnd={picking === "to"}
          onDaySelect={onDaySelect}
        />
        <p className="mt-3 text-center text-xs text-muted">
          {picking === "from" ? "Chọn ngày bắt đầu" : "Chọn ngày kết thúc"}
        </p>
      </DateDialogShell>
    </div>
  );
}
