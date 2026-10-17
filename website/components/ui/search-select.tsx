"use client";

import {
  useCallback,
  useEffect,
  useId,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
  type KeyboardEvent,
  type ReactNode,
} from "react";
import { createPortal } from "react-dom";
import { focusRing } from "@/components/ui/admin-list-ui";
import { OpsIcon, type OpsIconName } from "@/components/ui/ops-icons";

export type SearchSelectOption = {
  value: string;
  label: string;
  description?: string;
};

export type SearchSelectProps = {
  label: string;
  value: string | null;
  placeholder?: string;
  emptyLabel?: string;
  clearLabel?: string;
  disabled?: boolean;
  icon?: OpsIconName;
  /** Static options — filtered client-side by the search query. */
  options?: readonly SearchSelectOption[];
  /** Async loader — used when `options` is omitted. */
  loadOptions?: (query: string) => Promise<SearchSelectOption[]>;
  onChange: (value: string | null, option: SearchSelectOption | null) => void;
  debounceMs?: number;
  trailing?: ReactNode;
};

type PanelPlacement = "bottom" | "top";

function filterStaticOptions(
  options: readonly SearchSelectOption[],
  query: string,
): SearchSelectOption[] {
  const needle = query.trim().toLocaleLowerCase("vi");
  if (!needle) {
    return [...options];
  }
  return options.filter((option) => {
    const haystack = `${option.label} ${option.description ?? ""} ${option.value}`;
    return haystack.toLocaleLowerCase("vi").includes(needle);
  });
}

function resolvePlacement(trigger: HTMLElement | null): PanelPlacement {
  if (!trigger || typeof window === "undefined") {
    return "bottom";
  }
  const rect = trigger.getBoundingClientRect();
  const spaceBelow = window.innerHeight - rect.bottom;
  const spaceAbove = rect.top;
  const preferred = 280;
  if (spaceBelow < preferred && spaceAbove > spaceBelow) {
    return "top";
  }
  return "bottom";
}

function panelStyleFromTrigger(
  trigger: HTMLElement,
  placement: PanelPlacement,
): CSSProperties {
  const rect = trigger.getBoundingClientRect();
  const width = Math.max(rect.width, 160);
  const maxWidth = Math.min(window.innerWidth - 16, 384);
  const left = Math.min(
    Math.max(8, rect.left),
    window.innerWidth - Math.min(width, maxWidth) - 8,
  );
  const base: CSSProperties = {
    position: "fixed",
    left,
    width: Math.min(width, maxWidth),
    maxWidth,
    zIndex: 80,
  };
  if (placement === "top") {
    return {
      ...base,
      bottom: window.innerHeight - rect.top + 4,
    };
  }
  return {
    ...base,
    top: rect.bottom + 4,
  };
}

export function SearchSelect({
  label,
  value,
  placeholder = "Tìm và chọn…",
  emptyLabel = "Không có kết quả",
  clearLabel = "Bỏ chọn",
  disabled = false,
  icon = "search",
  options: staticOptions,
  loadOptions,
  onChange,
  debounceMs = 250,
  trailing,
}: SearchSelectProps) {
  const listboxId = useId();
  const triggerId = useId();
  const queryId = useId();
  const rootRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const panelRef = useRef<HTMLDivElement>(null);
  const queryRef = useRef<HTMLInputElement>(null);
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [asyncOptions, setAsyncOptions] = useState<SearchSelectOption[]>([]);
  const [loading, setLoading] = useState(false);
  const [selectedLabel, setSelectedLabel] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [activeIndex, setActiveIndex] = useState(0);
  const [panelStyle, setPanelStyle] = useState<CSSProperties>({});

  const isAsync = staticOptions == null;
  const resolvedOptions = useMemo(() => {
    if (!isAsync && staticOptions) {
      return filterStaticOptions(staticOptions, query);
    }
    return asyncOptions;
  }, [isAsync, staticOptions, query, asyncOptions]);

  const selectedFromStatic = useMemo(() => {
    if (!staticOptions || value == null) {
      return null;
    }
    return staticOptions.find((option) => option.value === value) ?? null;
  }, [staticOptions, value]);

  useEffect(() => {
    if (!open) {
      return;
    }
    const onPointerDown = (event: MouseEvent) => {
      const target = event.target as Node;
      if (
        rootRef.current?.contains(target) ||
        panelRef.current?.contains(target)
      ) {
        return;
      }
      setOpen(false);
    };
    const onKeyDown = (event: globalThis.KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault();
        setOpen(false);
      }
    };
    window.addEventListener("mousedown", onPointerDown);
    window.addEventListener("keydown", onKeyDown);
    return () => {
      window.removeEventListener("mousedown", onPointerDown);
      window.removeEventListener("keydown", onKeyDown);
    };
  }, [open]);

  useLayoutEffect(() => {
    if (!open || !triggerRef.current) {
      return;
    }
    const updatePosition = () => {
      const trigger = triggerRef.current;
      if (!trigger) {
        return;
      }
      const nextPlacement = resolvePlacement(trigger);
      setPanelStyle(panelStyleFromTrigger(trigger, nextPlacement));
    };
    updatePosition();
    window.addEventListener("resize", updatePosition);
    window.addEventListener("scroll", updatePosition, true);
    return () => {
      window.removeEventListener("resize", updatePosition);
      window.removeEventListener("scroll", updatePosition, true);
    };
  }, [open]);

  useEffect(() => {
    if (!open || !isAsync || !loadOptions) {
      return;
    }
    let cancelled = false;
    const delay = query === "" ? 0 : debounceMs;
    const timer = window.setTimeout(() => {
      setLoading(true);
      setError(null);
      void loadOptions(query.trim())
        .then((next) => {
          if (!cancelled) {
            setAsyncOptions(next);
          }
        })
        .catch(() => {
          if (!cancelled) {
            setAsyncOptions([]);
            setError("Không tải được danh sách.");
          }
        })
        .finally(() => {
          if (!cancelled) {
            setLoading(false);
          }
        });
    }, delay);
    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [open, query, loadOptions, debounceMs, isAsync]);

  const [prevResetToken, setPrevResetToken] = useState(
    () => `${open}:${resolvedOptions.length}`,
  );
  const currentResetToken = `${open}:${resolvedOptions.length}`;
  if (currentResetToken !== prevResetToken) {
    setPrevResetToken(currentResetToken);
    setActiveIndex(0);
  }

  const display =
    value == null
      ? placeholder
      : (selectedLabel ?? selectedFromStatic?.label ?? value);

  const selectableCount = resolvedOptions.length + 1;

  const commitSelection = useCallback(
    (option: SearchSelectOption | null) => {
      if (option == null) {
        setSelectedLabel(null);
        onChange(null, null);
      } else {
        setSelectedLabel(option.label);
        onChange(option.value, option);
      }
      setOpen(false);
      setQuery("");
    },
    [onChange],
  );

  const onTriggerKeyDown = (event: KeyboardEvent<HTMLButtonElement>) => {
    if (disabled) {
      return;
    }
    if (
      event.key === "ArrowDown" ||
      event.key === "Enter" ||
      event.key === " "
    ) {
      event.preventDefault();
      setOpen(true);
      setQuery("");
      window.requestAnimationFrame(() => queryRef.current?.focus());
    }
  };

  const onListKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    if (event.key === "Escape") {
      event.preventDefault();
      setOpen(false);
      return;
    }
    if (event.key === "ArrowDown") {
      event.preventDefault();
      setActiveIndex((prev) => (prev + 1) % selectableCount);
      return;
    }
    if (event.key === "ArrowUp") {
      event.preventDefault();
      setActiveIndex((prev) => (prev - 1 + selectableCount) % selectableCount);
      return;
    }
    if (event.key === "Enter") {
      event.preventDefault();
      if (activeIndex === 0) {
        commitSelection(null);
        return;
      }
      const option = resolvedOptions[activeIndex - 1];
      if (option) {
        commitSelection(option);
      }
    }
  };

  const panel =
    open && typeof document !== "undefined" ? (
      <div
        ref={panelRef}
        style={panelStyle}
        className="overflow-hidden rounded-xl border border-border bg-white shadow-lg"
        onKeyDown={onListKeyDown}
      >
        <div className="border-b border-border p-2">
          <label htmlFor={queryId} className="sr-only">
            Lọc {label}
          </label>
          <input
            ref={queryRef}
            id={queryId}
            type="search"
            autoComplete="off"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder={placeholder}
            className={`h-9 w-full rounded-lg border border-border bg-canvas px-3 text-sm text-ink placeholder:text-muted ${focusRing}`}
          />
        </div>
        <ul
          id={listboxId}
          role="listbox"
          aria-label={label}
          className="max-h-56 overflow-y-auto py-1"
        >
          <li>
            <button
              type="button"
              role="option"
              aria-selected={value == null}
              className={
                activeIndex === 0 || value == null
                  ? `flex w-full px-3 py-2 text-left text-sm cursor-pointer ${value == null ? "bg-brand/10 text-brand font-medium" : "text-muted"} ${activeIndex === 0 ? "bg-canvas" : ""} ${focusRing}`
                  : `flex w-full px-3 py-2 text-left text-sm text-muted cursor-pointer hover:bg-canvas ${focusRing}`
              }
              onMouseEnter={() => setActiveIndex(0)}
              onClick={() => commitSelection(null)}
            >
              {clearLabel}
            </button>
          </li>
          {loading ? (
            <li className="px-3 py-2 text-sm text-muted" role="status">
              Đang tìm…
            </li>
          ) : null}
          {error ? (
            <li className="px-3 py-2 text-sm text-danger" role="alert">
              {error}
            </li>
          ) : null}
          {!loading && !error && resolvedOptions.length === 0 ? (
            <li className="px-3 py-2 text-sm text-muted">{emptyLabel}</li>
          ) : null}
          {resolvedOptions.map((option, index) => {
            const optionIndex = index + 1;
            const selected = value === option.value;
            const active = activeIndex === optionIndex;
            return (
              <li key={option.value}>
                <button
                  type="button"
                  role="option"
                  aria-selected={selected}
                  title={option.label}
                  className={
                    selected
                      ? `flex w-full flex-col px-3 py-2 text-left text-sm cursor-pointer bg-brand/10 text-brand ${active ? "ring-1 ring-inset ring-brand/30" : ""} ${focusRing}`
                      : `flex w-full flex-col px-3 py-2 text-left text-sm cursor-pointer text-ink hover:bg-canvas ${active ? "bg-canvas" : ""} ${focusRing}`
                  }
                  onMouseEnter={() => setActiveIndex(optionIndex)}
                  onClick={() => commitSelection(option)}
                >
                  <span className="font-medium break-words">
                    {option.label}
                  </span>
                  {option.description ? (
                    <span className="text-xs text-muted break-words">
                      {option.description}
                    </span>
                  ) : null}
                </button>
              </li>
            );
          })}
        </ul>
      </div>
    ) : null;

  return (
    <div ref={rootRef} className="relative min-w-0">
      <label htmlFor={triggerId} className="text-xs font-medium text-muted">
        {label}
      </label>
      <div className="mt-1.5 flex gap-2">
        <button
          ref={triggerRef}
          type="button"
          id={triggerId}
          disabled={disabled}
          title={value == null ? undefined : display}
          aria-haspopup="listbox"
          aria-expanded={open}
          aria-controls={listboxId}
          onClick={() => {
            if (disabled) {
              return;
            }
            setOpen((prev) => {
              const next = !prev;
              if (next) {
                setQuery("");
                window.requestAnimationFrame(() => queryRef.current?.focus());
              }
              return next;
            });
          }}
          onKeyDown={onTriggerKeyDown}
          className={`flex h-10 min-w-[10rem] flex-1 items-center gap-2 rounded-xl border border-border bg-white px-3 text-left text-sm text-ink cursor-pointer hover:border-brand/40 transition-colors disabled:cursor-not-allowed disabled:opacity-50 ${focusRing}`}
        >
          <OpsIcon name={icon} className="size-4 shrink-0 text-muted" />
          <span
            title={value == null ? undefined : display}
            className={`min-w-0 flex-1 text-left leading-snug ${value == null ? "truncate text-muted" : "line-clamp-2 break-words"}`}
          >
            {display}
          </span>
          <OpsIcon name="chevron" className="size-4 shrink-0 text-muted" />
        </button>
        {trailing}
      </div>
      {panel ? createPortal(panel, document.body) : null}
    </div>
  );
}
