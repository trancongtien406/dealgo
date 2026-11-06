"use client";

import Link from "next/link";
import {
  Suspense,
  useCallback,
  useEffect,
  useState,
  type ReactNode,
} from "react";
import { AdminNav } from "@/components/layout/admin-nav";
import { BrandMark } from "@/components/layout/brand-mark";
import { LogoutButton } from "@/components/layout/logout-button";
import { NotificationInbox } from "@/components/layout/notification-inbox";
import { AdminPageSkeleton } from "@/components/ui/admin-state-ui";
import { AdminToaster } from "@/components/ui/admin-toaster";
import {
  CommandPalette,
  CommandPaletteTrigger,
} from "@/components/ui/command-palette";
import { OpsIcon } from "@/components/ui/ops-icons";
import { ThemeToggle } from "@/components/theme/theme-toggle";

const focusRing =
  "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ink";

const LG_QUERY = "(min-width: 1024px)";
const RAIL_WIDTH = "lg:w-[72px]";
const EXPANDED_WIDTH = "lg:w-[260px]";

function NavFallback({ collapsed }: { collapsed: boolean }) {
  return (
    <div
      className={collapsed ? "space-y-2 px-2 pb-4" : "space-y-2 px-3 pb-4"}
      aria-hidden="true"
    >
      {Array.from({ length: 8 }, (_, index) => (
        <div
          key={index}
          className={
            collapsed
              ? "mx-auto size-9 animate-pulse rounded-xl bg-canvas"
              : "h-9 animate-pulse rounded-xl bg-canvas"
          }
        />
      ))}
    </div>
  );
}

export function AdminShell({ children }: { children: ReactNode }) {
  const [mobileOpen, setMobileOpen] = useState(false);
  const [desktopCollapsed, setDesktopCollapsed] = useState(false);
  const [paletteOpen, setPaletteOpen] = useState(false);

  const closeMobile = useCallback(() => setMobileOpen(false), []);

  useEffect(() => {
    if (!mobileOpen) {
      return;
    }
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setMobileOpen(false);
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [mobileOpen]);

  useEffect(() => {
    if (!mobileOpen) {
      return;
    }
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = previous;
    };
  }, [mobileOpen]);

  useEffect(() => {
    const mq = window.matchMedia(LG_QUERY);
    const onChange = () => {
      if (mq.matches) {
        setMobileOpen(false);
      }
    };
    mq.addEventListener("change", onChange);
    return () => mq.removeEventListener("change", onChange);
  }, []);

  const toggleNav = () => {
    if (window.matchMedia(LG_QUERY).matches) {
      setDesktopCollapsed((value) => !value);
      return;
    }
    setMobileOpen((value) => !value);
  };

  return (
    <div className="min-h-screen overflow-x-clip bg-canvas lg:flex">
      {mobileOpen ? (
        <button
          type="button"
          aria-label="Đóng menu điều hướng"
          className="fixed inset-0 z-40 bg-ink/40 lg:hidden cursor-pointer"
          onClick={closeMobile}
        />
      ) : null}

      <aside
        id="admin-sidebar"
        className={[
          "fixed inset-y-0 left-0 z-50 flex max-w-[85vw] flex-col border-r border-border bg-white transition-[transform,width] duration-200 ease-out lg:sticky lg:top-0 lg:z-30 lg:h-screen lg:max-h-screen lg:shrink-0 lg:self-start lg:overflow-y-auto lg:translate-x-0 lg:pointer-events-auto lg:visible",
          // Mobile drawer: off-canvas when closed — must not steal clicks.
          mobileOpen
            ? "w-[260px] translate-x-0"
            : "w-[260px] -translate-x-full max-lg:pointer-events-none max-lg:invisible",
          desktopCollapsed ? RAIL_WIDTH : EXPANDED_WIDTH,
        ].join(" ")}
      >
        <div
          className={
            desktopCollapsed
              ? "flex h-16 shrink-0 items-center justify-center px-2"
              : "flex h-16 shrink-0 items-center justify-between gap-2 px-4"
          }
        >
          <Link
            href="/overview"
            className={`rounded-md ${focusRing} ${desktopCollapsed ? "lg:grid lg:size-10 lg:place-items-center" : ""}`}
            onClick={closeMobile}
            title="DealGo"
          >
            {desktopCollapsed ? (
              <span className="hidden lg:inline-flex">
                <BrandMark compact />
              </span>
            ) : null}
            <span className={desktopCollapsed ? "lg:hidden" : ""}>
              <BrandMark />
            </span>
          </Link>
          <button
            type="button"
            aria-label="Đóng menu"
            onClick={closeMobile}
            className={`grid size-9 place-items-center rounded-lg text-ink hover:bg-canvas transition-colors cursor-pointer lg:hidden ${focusRing}`}
          >
            <OpsIcon name="close" className="size-5" />
          </button>
        </div>
        <div className="min-h-0 flex-1 overflow-y-auto">
          <Suspense fallback={<NavFallback collapsed={desktopCollapsed} />}>
            <AdminNav onNavigate={closeMobile} collapsed={desktopCollapsed} />
          </Suspense>
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-30 flex h-16 shrink-0 items-center gap-3 border-b border-border bg-white px-4 sm:px-6">
          <button
            type="button"
            aria-label={
              desktopCollapsed
                ? "Mở rộng thanh điều hướng"
                : "Thu gọn thanh điều hướng"
            }
            aria-controls="admin-sidebar"
            aria-expanded={mobileOpen || !desktopCollapsed}
            onClick={toggleNav}
            className={`grid size-10 shrink-0 place-items-center rounded-full border border-border text-ink hover:bg-canvas transition-colors cursor-pointer ${focusRing}`}
          >
            <OpsIcon name="menu" className="size-5" />
          </button>
          <Link
            href="/overview"
            className="flex items-center gap-2 lg:hidden shrink-0"
            title="DealGo Quản trị"
          >
            <BrandMark compact className="size-8" />
            <span className="hidden sm:inline-flex text-base font-black tracking-tight leading-none">
              <span className="text-[#6D28D9]">Deal</span>
              <span className="text-[#16A34A]">Go</span>
            </span>
          </Link>
          <div className="relative min-w-0 flex-1">
            <CommandPaletteTrigger onOpen={() => setPaletteOpen(true)} />
          </div>
          <div className="ml-auto flex min-w-0 shrink-0 items-center gap-2 sm:gap-3">
            <ThemeToggle />
            <NotificationInbox />
            <Link
              href="/staff"
              className={`hidden min-w-0 items-center gap-2 rounded-xl p-1 hover:bg-canvas transition-colors cursor-pointer sm:flex group ${focusRing}`}
              title="Xem danh sách nhân viên & phân quyền hệ thống"
            >
              <span
                className="grid size-10 shrink-0 place-items-center rounded-full bg-brand/10 text-brand group-hover:bg-brand/20 transition-colors"
                aria-hidden="true"
              >
                <OpsIcon name="user" className="size-5" />
              </span>
              <div className="min-w-0 leading-tight">
                <p className="truncate text-sm font-semibold text-ink group-hover:text-brand transition-colors">
                  Điều hành Viên DealGo
                </p>
                <p className="truncate text-xs text-muted">Ban Quản trị Ops</p>
              </div>
            </Link>
            <LogoutButton />
          </div>
        </header>
        <main className="min-w-0 flex-1 px-4 py-5 sm:px-6 lg:px-8">
          <Suspense fallback={<AdminPageSkeleton />}>{children}</Suspense>
        </main>
      </div>

      <CommandPalette open={paletteOpen} onOpenChange={setPaletteOpen} />
      <AdminToaster />
    </div>
  );
}
