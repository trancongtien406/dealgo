"use client";

import { OpsIcon } from "@/components/ui/ops-icons";
import { useTheme } from "@/components/theme/theme-provider";
import { useIsMounted } from "@/lib/use-is-mounted";

const focusRing =
  "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ink";

export function ThemeToggle({
  className = "",
  compact = false,
}: {
  className?: string;
  compact?: boolean;
}) {
  const { resolvedTheme, toggleTheme } = useTheme();
  const mounted = useIsMounted();

  const isDark = mounted && resolvedTheme === "dark";

  return (
    <button
      type="button"
      onClick={toggleTheme}
      aria-label={
        isDark ? "Chuyển sang giao diện sáng" : "Chuyển sang giao diện tối"
      }
      title={
        isDark ? "Chuyển sang giao diện sáng" : "Chuyển sang giao diện tối"
      }
      className={`group relative grid size-10 place-items-center rounded-xl border border-border bg-white text-ink hover:bg-canvas hover:text-brand transition-all cursor-pointer shadow-2xs ${focusRing} ${className}`}
    >
      <div className="relative size-5">
        <OpsIcon
          name="sun"
          className={`absolute inset-0 size-5 text-amber-500 transition-all duration-300 transform ${
            isDark
              ? "rotate-0 scale-100 opacity-100"
              : "-rotate-90 scale-0 opacity-0"
          }`}
        />
        <OpsIcon
          name="moon"
          className={`absolute inset-0 size-5 text-indigo-500 transition-all duration-300 transform ${
            isDark
              ? "rotate-90 scale-0 opacity-0"
              : "rotate-0 scale-100 opacity-100"
          }`}
        />
      </div>
      {!compact && (
        <span className="sr-only">
          {isDark ? "Giao diện tối đang bật" : "Giao diện sáng đang bật"}
        </span>
      )}
    </button>
  );
}
