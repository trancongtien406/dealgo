"use client";

import { useRouter } from "next/navigation";
import {
  useCallback,
  useEffect,
  useId,
  useMemo,
  useRef,
  useState,
} from "react";
import { focusRing } from "@/components/ui/admin-list-ui";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  flattenAdminNavItemsForPalette,
  type AdminNavItem,
} from "@/lib/admin-nav-items";

function normalize(text: string) {
  return text.toLocaleLowerCase("vi").normalize("NFD").replace(/\p{M}/gu, "");
}

function matchesItem(item: AdminNavItem, query: string) {
  if (!query) {
    return true;
  }
  const haystack = normalize(
    [item.label, item.href, ...(item.keywords ?? [])].join(" "),
  );
  return query.split(/\s+/).every((part) => haystack.includes(part));
}

export function CommandPalette({
  open,
  onOpenChange,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const router = useRouter();
  const titleId = useId();
  const inputRef = useRef<HTMLInputElement>(null);
  const [query, setQuery] = useState("");
  const [activeIndex, setActiveIndex] = useState(0);
  const items = useMemo(() => flattenAdminNavItemsForPalette(), []);

  const filtered = useMemo(() => {
    const normalized = normalize(query.trim());
    return items.filter((item) => matchesItem(item, normalized));
  }, [items, query]);

  const [prevOpen, setPrevOpen] = useState(open);
  const [prevQuery, setPrevQuery] = useState(query);

  if (open !== prevOpen) {
    setPrevOpen(open);
    if (open) {
      setQuery("");
      setActiveIndex(0);
    }
  }

  if (query !== prevQuery) {
    setPrevQuery(query);
    setActiveIndex(0);
  }

  useEffect(() => {
    if (!open) {
      return;
    }
    const frame = window.requestAnimationFrame(() => {
      inputRef.current?.focus();
    });
    return () => window.cancelAnimationFrame(frame);
  }, [open]);

  const close = useCallback(() => onOpenChange(false), [onOpenChange]);

  const go = useCallback(
    (href: string) => {
      close();
      // Soft push first; if the dialog unmount races the transition, hard-assign.
      router.push(href);
      window.setTimeout(() => {
        if (window.location.pathname !== href) {
          window.location.assign(href);
        }
      }, 80);
    },
    [close, router],
  );

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const meta = event.metaKey || event.ctrlKey;
      if (meta && event.key.toLowerCase() === "k") {
        event.preventDefault();
        onOpenChange(!open);
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [open, onOpenChange]);

  if (!open) {
    return null;
  }

  return (
    <div
      className="fixed inset-0 z-[60] flex items-start justify-center bg-ink/40 p-4 pt-[12vh] sm:pt-[16vh]"
      role="presentation"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) {
          close();
        }
      }}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        className="w-full max-w-lg overflow-hidden rounded-2xl border border-border bg-white shadow-xl"
      >
        <h2 id={titleId} className="sr-only">
          Tìm kiếm chức năng quản trị
        </h2>
        <div className="flex items-center gap-2 border-b border-border px-3">
          <OpsIcon name="search" className="size-4 shrink-0 text-muted" />
          <input
            ref={inputRef}
            type="search"
            autoComplete="off"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === "Escape") {
                event.preventDefault();
                close();
                return;
              }
              if (event.key === "ArrowDown") {
                event.preventDefault();
                setActiveIndex((index) =>
                  Math.min(index + 1, Math.max(filtered.length - 1, 0)),
                );
                return;
              }
              if (event.key === "ArrowUp") {
                event.preventDefault();
                setActiveIndex((index) => Math.max(index - 1, 0));
                return;
              }
              if (event.key === "Enter") {
                event.preventDefault();
                const target = filtered[activeIndex];
                if (target) {
                  go(target.href);
                }
              }
            }}
            placeholder="Tìm chuyến xe, đơn hàng, khách hàng, cài đặt…"
            className={`h-12 w-full bg-transparent text-sm text-ink placeholder:text-muted outline-none ${focusRing}`}
          />
          <kbd className="hidden shrink-0 rounded-md border border-border bg-canvas px-1.5 py-0.5 text-[10px] font-medium text-muted sm:inline">
            Esc
          </kbd>
        </div>
        <ul
          role="listbox"
          aria-label="Kết quả tìm kiếm"
          className="max-h-80 overflow-y-auto py-2"
        >
          {filtered.length === 0 ? (
            <li className="px-4 py-6 text-center text-sm text-muted">
              Không có chức năng khớp với “{query}”.
            </li>
          ) : (
            filtered.map((item, index) => {
              const active = index === activeIndex;
              return (
                <li key={item.href} role="option" aria-selected={active}>
                  <button
                    type="button"
                    onMouseEnter={() => setActiveIndex(index)}
                    onClick={() => go(item.href)}
                    className={
                      active
                        ? `flex w-full items-center gap-3 px-4 py-2.5 text-left bg-brand/10 text-brand ${focusRing}`
                        : `flex w-full items-center gap-3 px-4 py-2.5 text-left text-ink hover:bg-canvas ${focusRing}`
                    }
                  >
                    <OpsIcon
                      name={item.icon}
                      className={`size-4 shrink-0 ${active ? "" : "text-muted"}`}
                    />
                    <span className="min-w-0 flex-1 truncate text-sm font-medium">
                      {item.label}
                    </span>
                    <span className="truncate text-xs text-muted">
                      {item.href}
                    </span>
                  </button>
                </li>
              );
            })
          )}
        </ul>
        <p className="border-t border-border px-4 py-2 text-xs text-muted">
          Điều hướng bằng ↑ ↓ · Enter để mở · Esc để đóng
        </p>
      </div>
    </div>
  );
}

export function CommandPaletteTrigger({ onOpen }: { onOpen: () => void }) {
  return (
    <button
      type="button"
      onClick={onOpen}
      className={`relative flex h-10 w-full min-w-0 items-center gap-2 rounded-full border border-border bg-canvas px-3 text-left text-sm text-muted hover:border-brand/40 hover:text-ink transition-colors cursor-pointer ${focusRing}`}
    >
      <OpsIcon name="search" className="size-4 shrink-0" />
      <span className="min-w-0 flex-1 truncate">
        Tìm chức năng, chuyến xe, đơn hàng…
      </span>
      <kbd className="hidden shrink-0 items-center gap-0.5 rounded-md border border-border bg-white px-1.5 py-0.5 text-[10px] font-medium text-muted sm:inline-flex">
        ⌘/Ctrl K
      </kbd>
    </button>
  );
}
