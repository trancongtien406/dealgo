"use client";

import Link from "next/link";
import { OpsIcon, type OpsIconName } from "@/components/ui/ops-icons";
import type { StatusTone } from "@/lib/admin-format";

const iconTone: Record<StatusTone, string> = {
  brand: "bg-brand/10 text-brand",
  food: "bg-food/10 text-food",
  delivery: "bg-delivery/10 text-delivery",
  success: "bg-success/10 text-success",
  danger: "bg-danger/10 text-danger",
};

export type OpsActivityItem = {
  id: string;
  title: string;
  detail: string;
  time: string;
  tone: StatusTone;
  icon: OpsIconName;
};

type OpsActivityFeedProps = {
  title: string;
  items: readonly OpsActivityItem[];
  viewAllHref?: string;
  emptyMessage?: string;
  className?: string;
};

export function OpsActivityFeed({
  title,
  items,
  viewAllHref,
  emptyMessage = "Chưa có hoạt động gần đây.",
  className = "",
}: OpsActivityFeedProps) {
  return (
    <section
      className={`flex min-h-0 min-w-0 flex-col rounded-2xl border border-border bg-white p-4 shadow-sm sm:p-5 ${className}`.trim()}
    >
      <div className="flex items-center justify-between gap-3">
        <h2 className="text-base font-semibold text-ink">{title}</h2>
        {viewAllHref ? (
          <Link
            href={viewAllHref}
            className="shrink-0 text-sm font-medium text-brand hover:underline"
          >
            Xem tất cả
          </Link>
        ) : null}
      </div>
      {items.length === 0 ? (
        <p className="mt-4 text-sm text-muted">{emptyMessage}</p>
      ) : (
        <ul className="mt-4 space-y-4">
          {items.map((item) => (
            <li key={item.id} className="flex items-start gap-3">
              <span
                className={`grid size-10 shrink-0 place-items-center rounded-full ${iconTone[item.tone]}`}
              >
                <OpsIcon name={item.icon} className="size-5" />
              </span>
              <div className="min-w-0 flex-1">
                <div className="flex items-start justify-between gap-3">
                  <p className="text-sm font-medium text-ink">{item.title}</p>
                  <p className="shrink-0 text-xs text-muted">{item.time}</p>
                </div>
                <p className="mt-0.5 text-sm leading-5 break-words text-muted">
                  {item.detail}
                </p>
              </div>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
