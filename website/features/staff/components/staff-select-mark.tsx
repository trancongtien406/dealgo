"use client";

import { OpsIcon } from "@/components/ui/ops-icons";
import { focusRing } from "@/components/ui/admin-list-ui";

export function SelectMark({
  checked,
  label,
  onChange,
}: {
  checked: boolean;
  label: string;
  onChange?: () => void;
}) {
  return (
    <button
      type="button"
      role="checkbox"
      aria-checked={checked}
      aria-label={label}
      onClick={onChange}
      className={`grid size-4 place-items-center rounded border transition-colors cursor-pointer ${
        checked
          ? "border-brand bg-brand text-white"
          : "border-border bg-white text-transparent hover:border-brand/50"
      } ${focusRing}`}
    >
      <OpsIcon name="check" className="size-3" />
    </button>
  );
}
