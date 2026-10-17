"use client";

import Link from "next/link";
import { OpsIcon, type OpsIconName } from "@/components/ui/ops-icons";
import { countFormat, shareFormat, type StatusTone } from "@/lib/admin-format";

const iconTone: Record<StatusTone, string> = {
  brand: "bg-brand/10 text-brand",
  food: "bg-food/10 text-food",
  delivery: "bg-delivery/10 text-delivery",
  success: "bg-success/10 text-success",
  danger: "bg-danger/10 text-danger",
};

const barTone: Record<StatusTone, string> = {
  brand: "bg-brand",
  food: "bg-food",
  delivery: "bg-delivery",
  success: "bg-success",
  danger: "bg-danger",
};

const footTone: Record<StatusTone, string> = {
  brand: "bg-brand/5",
  food: "bg-food/5",
  delivery: "bg-delivery/5",
  success: "bg-success/5",
  danger: "bg-danger/5",
};

export type OpsBreakdownRow = {
  name: string;
  count: number;
  share: number;
  /** Optional stable id when `name` may collide after display normalization. */
  id?: string;
};

type OpsBreakdownTableProps = {
  title: string;
  nameHeader: string;
  countHeader: string;
  icon: OpsIconName;
  tone: StatusTone;
  rows: readonly OpsBreakdownRow[];
  total: number;
  viewAllHref?: string;
  emptyMessage?: string;
};

export function OpsBreakdownTable({
  title,
  nameHeader,
  countHeader,
  icon,
  tone,
  rows,
  total,
  viewAllHref,
  emptyMessage = "Chưa có dữ liệu phân bổ.",
}: OpsBreakdownTableProps) {
  return (
    <section className="flex min-h-0 min-w-0 flex-col rounded-2xl border border-border bg-white p-4 shadow-sm sm:p-5">
      <div className="flex items-center justify-between gap-3">
        <div className="flex min-w-0 items-center gap-2">
          <span
            className={`grid size-9 shrink-0 place-items-center rounded-full ${iconTone[tone]}`}
          >
            <OpsIcon name={icon} className="size-4" />
          </span>
          <h2 className="truncate text-base font-semibold text-ink">{title}</h2>
        </div>
        {viewAllHref ? (
          <Link
            href={viewAllHref}
            className="shrink-0 text-sm font-medium text-brand hover:underline"
          >
            Xem tất cả
          </Link>
        ) : null}
      </div>

      {rows.length === 0 ? (
        <p className="mt-4 text-sm text-muted">{emptyMessage}</p>
      ) : (
        <div className="mt-4 min-w-0 overflow-x-auto">
          <table className="w-full min-w-[16rem] border-collapse text-left text-sm">
            <thead>
              <tr className="border-b border-border text-muted">
                <th className="pb-2 pr-2 font-medium">#</th>
                <th className="pb-2 pr-2 font-medium">{nameHeader}</th>
                <th className="pb-2 pr-2 text-right font-medium">
                  {countHeader}
                </th>
                <th className="pb-2 font-medium">Tỷ lệ</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row, index) => (
                <tr
                  key={row.id ?? `${row.name}::${index}`}
                  className="border-b border-border/70"
                >
                  <td className="py-2.5 pr-2 tabular-nums text-muted">
                    {index + 1}
                  </td>
                  <td className="max-w-[10rem] truncate py-2.5 pr-2 font-medium text-ink">
                    {row.name}
                  </td>
                  <td className="py-2.5 pr-2 text-right tabular-nums text-ink">
                    {countFormat.format(row.count)}
                  </td>
                  <td className="py-2.5">
                    <div className="flex min-w-[6.5rem] items-center gap-2">
                      <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-canvas">
                        <div
                          className={`h-full rounded-full ${barTone[tone]}`}
                          style={{
                            width: `${Math.min(100, Math.max(0, row.share))}%`,
                          }}
                        />
                      </div>
                      <span className="w-10 shrink-0 text-right tabular-nums text-muted">
                        {shareFormat.format(row.share)}%
                      </span>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
            <tfoot>
              <tr className={footTone[tone]}>
                <td className="rounded-bl-lg py-2.5 pr-2" colSpan={2}>
                  <span className="font-semibold text-ink">Tổng cộng</span>
                </td>
                <td className="py-2.5 pr-2 text-right font-semibold tabular-nums text-ink">
                  {countFormat.format(total)}
                </td>
                <td className="rounded-br-lg py-2.5 font-semibold tabular-nums text-ink">
                  100%
                </td>
              </tr>
            </tfoot>
          </table>
        </div>
      )}
    </section>
  );
}
