"use client";

import { useEffect, useId, useRef, useState } from "react";
import { OpsIcon } from "@/components/ui/ops-icons";
import { focusRing } from "@/components/ui/admin-list-ui";
import {
  DateDialogShell,
  MonthCalendar,
  addDaysIso,
  compareIso,
  formatIso,
  startOfMonthIso,
  todayIso,
  type DateIso,
  type DateRangeValue,
} from "@/components/ui/date-picker";
import { toast } from "sonner";

export type PeriodPresetKey =
  "today" | "yesterday" | "7days" | "30days" | "this_month" | "custom" | "all";

export interface PeriodPreset {
  key: PeriodPresetKey;
  label: string;
  description?: string;
}

export const PERIOD_PRESETS: readonly PeriodPreset[] = [
  { key: "today", label: "Hôm nay", description: "Từ đầu ngày tới hiện tại" },
  {
    key: "yesterday",
    label: "Hôm qua",
    description: "Trọn vẹn 24h ngày hôm qua",
  },
  { key: "7days", label: "7 ngày qua", description: "Tuần gần nhất" },
  { key: "30days", label: "30 ngày qua", description: "Tháng gần nhất" },
  { key: "this_month", label: "Tháng này", description: "Từ ngày 1 của tháng" },
  { key: "all", label: "Tất cả thời gian", description: "Không giới hạn ngày" },
];

function calculateRangeForPreset(key: PeriodPresetKey): DateRangeValue {
  const todayStr = todayIso();

  if (key === "today") {
    return { from: todayStr, to: todayStr };
  }
  if (key === "yesterday") {
    const yestStr = addDaysIso(todayStr, -1);
    return { from: yestStr, to: yestStr };
  }
  if (key === "7days") {
    return { from: addDaysIso(todayStr, -6), to: todayStr };
  }
  if (key === "30days") {
    return { from: addDaysIso(todayStr, -29), to: todayStr };
  }
  if (key === "this_month") {
    return { from: startOfMonthIso(todayStr), to: todayStr };
  }
  return { from: null, to: null };
}

export interface AdminHeaderDateFilterProps {
  value?: DateRangeValue;
  onChange?: (range: DateRangeValue, label: string) => void;
  defaultPreset?: PeriodPresetKey;
  className?: string;
  labelPrefix?: string;
}

/**
 * Interactive Header Date Filter button.
 * Clicking opens a sleek popover with quick presets (Hôm nay, 7 ngày qua, v.v.)
 * and a custom DateRangePicker dialog trigger.
 */
export function AdminHeaderDateFilter({
  value,
  onChange,
  defaultPreset = "today",
  className = "",
  labelPrefix,
}: AdminHeaderDateFilterProps) {
  const [open, setOpen] = useState(false);
  const [customDialogOpen, setCustomDialogOpen] = useState(false);
  const [activePreset, setActivePreset] =
    useState<PeriodPresetKey>(defaultPreset);
  const [internalRange, setInternalRange] = useState<DateRangeValue>(
    () => value ?? calculateRangeForPreset(defaultPreset),
  );

  // Custom picker state
  const [draft, setDraft] = useState<DateRangeValue>(internalRange);
  const [picking, setPicking] = useState<"from" | "to">("from");
  const [monthCursor, setMonthCursor] = useState(() =>
    startOfMonthIso(internalRange.from ?? internalRange.to ?? todayIso()),
  );

  const containerRef = useRef<HTMLDivElement>(null);
  const menuId = useId();
  const customDialogTitleId = useId();

  // Click outside and Escape handling for preset menu
  useEffect(() => {
    if (!open) return;
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    const onPointerDown = (e: MouseEvent) => {
      if (
        containerRef.current &&
        !containerRef.current.contains(e.target as Node)
      ) {
        setOpen(false);
      }
    };
    window.addEventListener("keydown", onKeyDown);
    window.addEventListener("pointerdown", onPointerDown);
    return () => {
      window.removeEventListener("keydown", onKeyDown);
      window.removeEventListener("pointerdown", onPointerDown);
    };
  }, [open]);

  const currentRange = value ?? internalRange;

  // Determine button display label
  let displayLabel: string;
  if (activePreset !== "custom") {
    const presetObj = PERIOD_PRESETS.find((p) => p.key === activePreset);
    displayLabel = presetObj ? presetObj.label : "Hôm nay";
  } else if (currentRange.from && currentRange.to) {
    if (currentRange.from === currentRange.to) {
      displayLabel = formatIso(currentRange.from);
    } else {
      displayLabel = `${formatIso(currentRange.from)} - ${formatIso(currentRange.to)}`;
    }
  } else if (currentRange.from) {
    displayLabel = `Từ ${formatIso(currentRange.from)}`;
  } else if (currentRange.to) {
    displayLabel = `Đến ${formatIso(currentRange.to)}`;
  } else {
    displayLabel = "Tất cả thời gian";
  }

  const handleSelectPreset = (key: PeriodPresetKey) => {
    if (key === "custom") {
      setOpen(false);
      setDraft(currentRange);
      setPicking("from");
      setMonthCursor(
        startOfMonthIso(currentRange.from ?? currentRange.to ?? todayIso()),
      );
      setCustomDialogOpen(true);
      return;
    }
    setActivePreset(key);
    const newRange = calculateRangeForPreset(key);
    setInternalRange(newRange);
    setOpen(false);

    const presetObj = PERIOD_PRESETS.find((p) => p.key === key);
    const label = presetObj ? presetObj.label : key;
    onChange?.(newRange, label);
    toast.success(`Đã áp dụng bộ lọc thời gian: ${label}`);
  };

  const handleDaySelect = (iso: DateIso) => {
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

  const handleApplyCustomRange = () => {
    let next = draft;
    if (next.from && next.to && compareIso(next.from, next.to) > 0) {
      next = { from: next.to, to: next.from };
    }
    setActivePreset("custom");
    setInternalRange(next);
    setCustomDialogOpen(false);

    const label =
      next.from && next.to
        ? `${formatIso(next.from)} - ${formatIso(next.to)}`
        : "Khoảng ngày tùy chọn";
    onChange?.(next, label);
    toast.success(`Đã áp dụng khoảng ngày: ${label}`);
  };

  return (
    <div ref={containerRef} className={`relative inline-block ${className}`}>
      <button
        type="button"
        aria-haspopup="menu"
        aria-expanded={open}
        aria-controls={menuId}
        onClick={() => setOpen((prev) => !prev)}
        className={`inline-flex h-10 items-center gap-2 rounded-xl border border-border bg-white px-3 text-sm font-medium text-ink shadow-xs transition-colors hover:bg-canvas hover:border-brand/40 cursor-pointer ${focusRing}`}
        title="Bấm để chọn khoảng thời gian lọc dữ liệu"
      >
        <OpsIcon name="calendar" className="size-4 shrink-0 text-brand" />
        <span className="truncate max-w-[200px]">
          {labelPrefix ? `${labelPrefix}: ` : ""}
          {displayLabel}
        </span>
        <OpsIcon
          name="chevron"
          className={`size-4 shrink-0 text-muted transition-transform duration-200 ${
            open ? "rotate-180" : ""
          }`}
        />
      </button>

      {open && (
        <div
          id={menuId}
          role="menu"
          className="absolute right-0 z-50 mt-1.5 w-64 origin-top-right rounded-2xl border border-border bg-white p-1.5 shadow-xl ring-1 ring-black/5 animate-in fade-in-50 zoom-in-95 duration-100"
        >
          <div className="px-3 py-2 border-b border-border mb-1">
            <p className="text-xs font-semibold text-ink uppercase tracking-wider">
              Chọn thời gian xem
            </p>
            <p className="text-[11px] text-muted mt-0.5">
              Cập nhật dữ liệu danh sách và chỉ số KPI
            </p>
          </div>

          <div className="space-y-0.5">
            {PERIOD_PRESETS.map((preset) => {
              const isSelected = activePreset === preset.key;
              return (
                <button
                  key={preset.key}
                  type="button"
                  role="menuitem"
                  onClick={() => handleSelectPreset(preset.key)}
                  className={`flex w-full items-center justify-between rounded-xl px-3 py-2 text-left text-xs transition-colors cursor-pointer ${
                    isSelected
                      ? "bg-brand/10 font-semibold text-brand"
                      : "text-ink hover:bg-canvas"
                  }`}
                >
                  <div>
                    <span className="block font-medium">{preset.label}</span>
                    {preset.description && (
                      <span className="block text-[11px] text-muted">
                        {preset.description}
                      </span>
                    )}
                  </div>
                  {isSelected && (
                    <OpsIcon
                      name="check"
                      className="size-4 shrink-0 text-brand"
                    />
                  )}
                </button>
              );
            })}

            <div className="my-1 border-t border-border" />

            <button
              type="button"
              role="menuitem"
              onClick={() => handleSelectPreset("custom")}
              className={`flex w-full items-center gap-2 rounded-xl px-3 py-2 text-left text-xs font-medium text-brand hover:bg-brand/5 transition-colors cursor-pointer ${
                activePreset === "custom" ? "bg-brand/10 font-semibold" : ""
              }`}
            >
              <OpsIcon name="sliders" className="size-3.5" />
              <span>Tùy chọn khoảng ngày cụ thể…</span>
            </button>
          </div>
        </div>
      )}

      {/* Custom Date Range Picker Dialog */}
      <DateDialogShell
        open={customDialogOpen}
        titleId={customDialogTitleId}
        title="Chọn khoảng ngày tùy chỉnh"
        onClose={() => setCustomDialogOpen(false)}
        footer={
          <>
            <button
              type="button"
              onClick={() => {
                setDraft({ from: null, to: null });
                setActivePreset("all");
                setInternalRange({ from: null, to: null });
                setCustomDialogOpen(false);
                onChange?.({ from: null, to: null }, "Tất cả thời gian");
                toast.success("Đã xóa bộ lọc thời gian");
              }}
              className={`inline-flex h-10 items-center rounded-xl border border-border bg-white px-3 text-sm font-medium text-ink cursor-pointer hover:bg-canvas ${focusRing}`}
            >
              Xóa lọc
            </button>
            <button
              type="button"
              onClick={handleApplyCustomRange}
              className={`inline-flex h-10 items-center rounded-xl border border-transparent bg-brand px-3 text-sm font-semibold text-white cursor-pointer hover:bg-brand/90 ${focusRing}`}
            >
              Áp dụng
            </button>
          </>
        }
      >
        <div className="mb-3 grid grid-cols-2 gap-2 text-sm">
          <button
            type="button"
            onClick={() => setPicking("from")}
            className={`rounded-xl border px-3 py-2 text-left cursor-pointer ${
              picking === "from"
                ? "border-brand bg-brand/5"
                : "border-border bg-white"
            } ${focusRing}`}
          >
            <span className="block text-xs text-muted">Từ ngày</span>
            <span className="font-medium text-ink">
              {formatIso(draft.from)}
            </span>
          </button>
          <button
            type="button"
            onClick={() => setPicking("to")}
            className={`rounded-xl border px-3 py-2 text-left cursor-pointer ${
              picking === "to"
                ? "border-brand bg-brand/5"
                : "border-border bg-white"
            } ${focusRing}`}
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
          onDaySelect={handleDaySelect}
        />
        <p className="mt-3 text-center text-xs text-muted">
          {picking === "from"
            ? "Bấm ngày để chọn ngày bắt đầu"
            : "Bấm ngày để chọn ngày kết thúc"}
        </p>
      </DateDialogShell>
    </div>
  );
}
