"use client";

import type { ReactNode } from "react";
import { focusRing, StatusChip } from "@/components/ui/admin-list-ui";

export function ConfigValue({ value }: { value: string }) {
  if (value === "confirm") {
    return <StatusChip tone="brand">Yêu cầu xác nhận</StatusChip>;
  }
  return <span className="font-medium break-words text-ink">{value}</span>;
}

export function ConfigRow({
  label,
  children,
}: {
  label: string;
  children: ReactNode;
}) {
  return (
    <div className="flex items-start justify-between gap-3 border-b border-border py-3 text-sm">
      <dt className="min-w-0 text-muted">{label}</dt>
      <dd className="max-w-[65%] text-right">{children}</dd>
    </div>
  );
}

export function InteractiveSwitch({
  id,
  label,
  checked,
  onChange,
}: {
  id: string;
  label: string;
  checked: boolean;
  onChange: (val: boolean) => void;
}) {
  return (
    <div className="flex items-center justify-between gap-3 border-b border-border py-3 last:border-b-0">
      <label htmlFor={id} className="min-w-0 text-sm text-ink cursor-pointer">
        {label}
      </label>
      <button
        id={id}
        type="button"
        role="switch"
        aria-checked={checked}
        onClick={() => onChange(!checked)}
        className={`relative h-6 w-11 shrink-0 rounded-full transition-colors cursor-pointer ${
          checked ? "bg-success" : "bg-canvas border border-border"
        } ${focusRing}`}
      >
        <span className="sr-only">{checked ? "Bật" : "Tắt"}</span>
        <span
          className={`absolute top-0.5 size-5 rounded-full bg-white shadow transition-all ${
            checked ? "right-0.5" : "left-0.5"
          }`}
        />
      </button>
    </div>
  );
}
