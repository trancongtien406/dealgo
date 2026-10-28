"use client";

import type { ReactNode } from "react";
import { focusRing, StatusChip } from "@/components/ui/admin-list-ui";
import { SOURCE_LABELS } from "@/features/integrations/mappers";
import type { FieldSource } from "@/features/integrations/types";

export const inputClass = `mt-1 block h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink disabled:bg-canvas disabled:text-muted ${focusRing}`;
export const primaryButton = `inline-flex h-10 items-center justify-center rounded-xl bg-brand px-4 text-sm font-semibold text-white disabled:opacity-50 cursor-pointer disabled:cursor-not-allowed ${focusRing}`;
export const secondaryButton = `inline-flex h-10 items-center justify-center rounded-xl border border-border bg-white px-4 text-sm font-medium text-ink hover:bg-canvas disabled:opacity-50 cursor-pointer disabled:cursor-not-allowed ${focusRing}`;

export function Card({ title, aside, children }: { title: string; aside?: ReactNode; children: ReactNode }) {
  return (
    <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm sm:p-5">
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
        <h2 className="text-base font-semibold text-ink">{title}</h2>
        {aside}
      </div>
      {children}
    </section>
  );
}

export function SourceTag({ source }: { source: FieldSource }) {
  if (source === "admin" || source === "unset") return null;
  return (
    <span className="ml-1.5 rounded bg-canvas px-1.5 py-0.5 text-[11px] font-medium text-muted">
      {SOURCE_LABELS[source]}
    </span>
  );
}

export function Field({
  label,
  source,
  children,
}: {
  label: string;
  source?: FieldSource;
  children: ReactNode;
}) {
  return (
    <label className="block min-w-0 text-sm font-medium text-ink">
      <span className="inline-flex items-center">
        {label}
        {source ? <SourceTag source={source} /> : null}
      </span>
      {children}
    </label>
  );
}

/** Write-only secret: shows whether a value is stored, input replaces it, "Xoá" clears the Admin value. */
export function SecretField({
  label,
  isSet,
  source,
  value,
  cleared,
  disabled,
  onChange,
  onClear,
}: {
  label: string;
  isSet: boolean;
  source: FieldSource | "unset";
  value: string;
  cleared: boolean;
  disabled: boolean;
  onChange: (value: string) => void;
  onClear: () => void;
}) {
  return (
    <div className="min-w-0 text-sm font-medium text-ink">
      <div className="flex items-center justify-between gap-2">
        <span className="inline-flex items-center">
          {label}
          <SourceTag source={source} />
        </span>
        {source === "admin" && isSet && !cleared ? (
          <button
            type="button"
            disabled={disabled}
            onClick={onClear}
            className={`min-h-6 rounded px-1 text-xs font-medium text-danger hover:underline ${focusRing}`}
          >
            Xoá
          </button>
        ) : null}
      </div>
      <input
        type="password"
        autoComplete="new-password"
        spellCheck={false}
        disabled={disabled}
        aria-label={label}
        className={inputClass}
        placeholder={cleared ? "Sẽ xoá khi lưu" : isSet ? "•••••••• đã lưu" : ""}
        value={value}
        onChange={(e) => onChange(e.target.value)}
      />
    </div>
  );
}

export function StatusLine({ configured, verified }: { configured: boolean; verified: boolean }) {
  return (
    <div className="flex flex-wrap items-center gap-2">
      {configured ? (
        <StatusChip tone="success" dot>Đã cấu hình</StatusChip>
      ) : (
        <StatusChip tone="food" dot>Chưa cấu hình</StatusChip>
      )}
      {configured ? (
        verified ? (
          <StatusChip tone="success" dot>Đã gửi thử OK</StatusChip>
        ) : (
          <StatusChip tone="danger" dot>Chưa gửi thử</StatusChip>
        )
      ) : null}
    </div>
  );
}
