import React, { useState } from "react";
import Link from "next/link";
import { OpsIcon, type OpsIconName } from "@/components/ui/ops-icons";
import { PreviewTabs, PreviewLink } from "@/components/ui/admin-list-ui";
import { focusRing } from "@/lib/admin-format";
import type { CmsItem } from "../types";
import { cmsStatusTone, cmsStatusLabel } from "../mappers";

const iconTone: Record<string, string> = {
  brand: "bg-brand/10 text-brand",
  food: "bg-food/10 text-food",
  delivery: "bg-delivery/10 text-delivery",
  success: "bg-success/10 text-success",
  danger: "bg-danger/10 text-danger",
};

interface NotificationsCmsSectionProps {
  cmsItemsList: CmsItem[];
  activeCmsTab: string;
  setActiveCmsTab: (tab: string) => void;
  isCmsPending: boolean;
  isCmsError: boolean;
  refetchCms: () => void;
}

export function NotificationsCmsSection({
  cmsItemsList,
  activeCmsTab,
  setActiveCmsTab,
  isCmsPending,
  isCmsError,
  refetchCms,
}: NotificationsCmsSectionProps) {
  const [readingCms, setReadingCms] = useState<CmsItem | null>(null);

  return (
    <>
      <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
        <div className="flex flex-wrap items-start justify-between gap-2">
          <div className="min-w-0">
            <h2 className="text-base font-semibold text-ink">
              Thư viện nội dung CMS
            </h2>
            <p className="mt-1 text-sm text-muted">
              Bài viết · Banner · Chính sách công khai
            </p>
          </div>
          <Link
            href="/settings/content"
            className={`inline-flex items-center gap-1 rounded-md text-sm font-semibold text-brand hover:underline cursor-pointer ${focusRing}`}
          >
            Quản lý CMS
            <OpsIcon name="arrowRight" className="size-4" />
          </Link>
        </div>

        <div className="mt-3">
          <PreviewTabs
            label="Loại nội dung CMS"
            current={activeCmsTab}
            onChange={setActiveCmsTab}
            tabs={["Tất cả", "Bài viết", "Banner", "Chính sách"]}
          />
        </div>

        {isCmsPending ? (
          <ul role="tabpanel" className="mt-3 space-y-3" aria-busy="true">
            {[1, 2, 3].map((idx) => (
              <li
                key={idx}
                className="flex items-center gap-3 py-2 px-2 animate-pulse"
              >
                <div className="size-9 shrink-0 rounded-full bg-canvas" />
                <div className="min-w-0 flex-1 space-y-1.5">
                  <div className="h-4 w-3/4 rounded bg-canvas" />
                  <div className="h-3 w-1/3 rounded bg-canvas" />
                </div>
                <div className="h-5 w-16 rounded bg-canvas" />
              </li>
            ))}
          </ul>
        ) : isCmsError ? (
          <div className="py-6 text-center">
            <p className="text-xs font-medium text-danger">
              Không thể kết nối máy chủ để tải nội dung CMS.
            </p>
            <button
              type="button"
              onClick={refetchCms}
              className="mt-2 text-xs font-semibold text-brand underline cursor-pointer"
            >
              Thử lại
            </button>
          </div>
        ) : cmsItemsList.length === 0 ? (
          <div className="py-8 text-center text-xs text-muted">
            Không tìm thấy nội dung CMS nào phù hợp.
          </div>
        ) : (
          <ul role="tabpanel" className="mt-2 divide-y divide-border">
            {cmsItemsList.map((item) => (
              <li
                key={item.id}
                onClick={() => setReadingCms(item)}
                className="flex items-center gap-3 py-3 cursor-pointer hover:bg-canvas/60 rounded-xl px-2 transition-colors"
              >
                <span
                  className={`grid size-9 shrink-0 place-items-center rounded-full ${
                    iconTone[item.tone] ?? "bg-brand/10 text-brand"
                  }`}
                >
                  <OpsIcon
                    name={(item.icon as OpsIconName) || "bell"}
                    className="size-4"
                  />
                </span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium text-ink">
                    {item.title}
                  </p>
                  <p className="text-xs text-muted">
                    {item.kind} · {item.date}
                  </p>
                </div>
                <span
                  className={`rounded-md px-2 py-0.5 text-xs font-bold ${cmsStatusTone(
                    item.status,
                  )}`}
                >
                  {cmsStatusLabel(item.status)}
                </span>
              </li>
            ))}
          </ul>
        )}
      </section>

      {/* Reading Modal: CMS Item */}
      {readingCms ? (
        <div
          role="dialog"
          aria-modal="true"
          className="fixed inset-0 z-50 flex items-center justify-center p-4"
        >
          <div
            className="fixed inset-0 bg-ink/40 backdrop-blur-xs transition-opacity"
            onClick={() => setReadingCms(null)}
          />
          <div className="relative z-10 w-full max-w-lg overflow-hidden rounded-2xl border border-border bg-white p-6 shadow-2xl transition-all">
            <div className="flex items-start justify-between gap-3 border-b border-border pb-4">
              <div className="min-w-0">
                <span className="inline-block rounded-md bg-canvas px-2 py-0.5 text-xs font-bold text-muted">
                  CMS · {readingCms.kind}
                </span>
                <h3 className="mt-1 text-lg font-bold text-ink">
                  {readingCms.title}
                </h3>
                <p className="text-xs text-muted">
                  Ngày phát hành: {readingCms.date}
                </p>
              </div>
              <button
                type="button"
                onClick={() => setReadingCms(null)}
                className="rounded-lg p-1 text-muted hover:bg-canvas hover:text-ink cursor-pointer"
              >
                <OpsIcon name="close" className="size-5" />
              </button>
            </div>

            <div className="mt-4 space-y-3 text-sm">
              <div className="rounded-xl border border-border bg-canvas/70 p-4">
                <p className="text-xs font-semibold text-muted uppercase">
                  Nội dung văn bản
                </p>
                <p className="mt-2 text-sm text-ink leading-relaxed break-words whitespace-pre-line max-h-60 overflow-y-auto">
                  {readingCms.body?.trim() ||
                    "Chưa có nội dung chi tiết cho bản ghi này."}
                </p>
              </div>
              <div className="flex items-center justify-between rounded-xl border border-border p-3 text-xs">
                <span className="text-muted">Trạng thái công khai:</span>
                <span
                  className={`rounded-md px-2 py-0.5 text-xs font-bold ${cmsStatusTone(
                    readingCms.status,
                  )}`}
                >
                  {cmsStatusLabel(readingCms.status)}
                </span>
              </div>
            </div>

            <div className="mt-6 flex justify-end gap-2 border-t border-border pt-4">
              <PreviewLink href="/settings/content" tone="ghost" compact>
                <OpsIcon name="sliders" className="size-3.5" />
                Mở CMS
              </PreviewLink>
              <button
                type="button"
                onClick={() => setReadingCms(null)}
                className="inline-flex items-center rounded-xl bg-canvas px-4 py-2 text-xs font-semibold text-ink hover:bg-border/60 cursor-pointer"
              >
                Đóng
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}
