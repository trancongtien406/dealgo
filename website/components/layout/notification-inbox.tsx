"use client";

import Link from "next/link";
import { useEffect, useId, useRef, useState } from "react";
import { OpsIcon } from "@/components/ui/ops-icons";
import { focusRing } from "@/components/ui/admin-list-ui";

/** Campaign API is not an ops inbox feed — empty until a real inbox exists. */
export function NotificationInbox() {
  const [open, setOpen] = useState(false);
  const panelId = useId();
  const buttonRef = useRef<HTMLButtonElement>(null);
  const panelRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) {
      return;
    }
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setOpen(false);
        buttonRef.current?.focus();
      }
    };
    const onPointer = (event: MouseEvent) => {
      const target = event.target as Node;
      if (
        panelRef.current?.contains(target) ||
        buttonRef.current?.contains(target)
      ) {
        return;
      }
      setOpen(false);
    };
    window.addEventListener("keydown", onKeyDown);
    window.addEventListener("mousedown", onPointer);
    return () => {
      window.removeEventListener("keydown", onKeyDown);
      window.removeEventListener("mousedown", onPointer);
    };
  }, [open]);

  return (
    <div className="relative">
      <button
        ref={buttonRef}
        type="button"
        aria-label="Thông báo"
        aria-expanded={open}
        aria-controls={panelId}
        onClick={() => setOpen((value) => !value)}
        className={`relative grid size-10 shrink-0 place-items-center rounded-full text-ink hover:bg-canvas transition-colors cursor-pointer ${focusRing}`}
      >
        <OpsIcon name="bell" className="size-5" />
      </button>
      {open ? (
        <div
          ref={panelRef}
          id={panelId}
          role="dialog"
          aria-label="Hộp thư thông báo"
          className="absolute top-12 right-0 z-40 w-[min(100vw-2rem,22rem)] overflow-hidden rounded-2xl border border-border bg-white shadow-lg"
        >
          <div className="flex items-center justify-between gap-2 border-b border-border px-4 py-3">
            <p className="text-sm font-semibold text-ink">Thông báo</p>
            <Link
              href="/notifications"
              onClick={() => setOpen(false)}
              className={`text-xs font-medium text-brand hover:underline cursor-pointer ${focusRing}`}
            >
              Xem tất cả
            </Link>
          </div>
          <div className="flex flex-col items-center px-4 py-10 text-center">
            <span className="grid size-11 place-items-center rounded-full bg-canvas text-muted">
              <OpsIcon name="bell" className="size-5" />
            </span>
            <p className="mt-3 text-sm font-semibold text-ink">
              Chưa có thông báo mới
            </p>
            <p className="mt-1 max-w-[16rem] text-xs leading-5 text-muted">
              Hộp thư vận hành sẽ hiển thị cảnh báo khi hệ thống có nguồn sự
              kiện realtime. Quản lý chiến dịch gửi thông báo tại trang Thông
              báo.
            </p>
            <Link
              href="/notifications"
              onClick={() => setOpen(false)}
              className={`mt-4 inline-flex h-9 items-center rounded-xl bg-brand px-3.5 text-xs font-semibold text-white hover:bg-brand/90 transition-colors ${focusRing}`}
            >
              Mở trang Thông báo
            </Link>
          </div>
        </div>
      ) : null}
    </div>
  );
}
