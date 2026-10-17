"use client";

import Link from "next/link";
import { BrandMark } from "@/components/layout/brand-mark";
import { OpsIcon } from "@/components/ui/ops-icons";
import { useCmsDocumentQuery } from "@/features/content-cms/hooks";

export function PrivacyClient() {
  const { data: doc, isPending } = useCmsDocumentQuery("PRIVACY");

  if (isPending || !doc) {
    return (
      <div className="min-h-screen bg-canvas text-ink flex flex-col items-center justify-center p-4">
        <OpsIcon
          name="refresh"
          className="size-8 animate-spin text-brand mb-3"
        />
        <p className="text-sm font-medium text-muted">
          Đang tải chính sách quyền riêng tư từ máy chủ DealGo...
        </p>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-canvas text-ink">
      {/* Top Header */}
      <header className="sticky top-0 z-30 border-b border-border bg-white/90 backdrop-blur-md">
        <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6">
          <Link href="/overview" className="flex items-center gap-2">
            <BrandMark />
          </Link>
          <div className="flex items-center gap-3">
            <Link
              href="/support"
              className="inline-flex h-9 items-center gap-1.5 rounded-lg border border-border px-3 text-xs font-medium text-ink hover:bg-canvas transition-colors"
            >
              <OpsIcon name="headset" className="size-3.5 text-muted" />
              Trung tâm hỗ trợ
            </Link>
            <Link
              href="/settings/content"
              className="inline-flex h-9 items-center gap-1.5 rounded-lg border border-brand/30 bg-brand/5 px-3 text-xs font-medium text-brand hover:bg-brand/10 transition-colors"
            >
              <OpsIcon name="settings" className="size-3.5" />
              Chỉnh sửa (Admin)
            </Link>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="mx-auto max-w-4xl px-4 py-10 sm:px-6 sm:py-16">
        <div className="border-b border-border pb-8">
          <div className="inline-flex items-center gap-2 rounded-full bg-success/10 px-3 py-1 text-xs font-medium text-success">
            <OpsIcon name="shield" className="size-3.5" />
            {doc.badge || "Tuân thủ Nghị định 13/2023/NĐ-CP"}
          </div>
          <h1 className="mt-4 text-3xl font-extrabold tracking-tight sm:text-4xl text-ink">
            {doc.title}
          </h1>
          <p className="mt-2 text-sm text-muted">
            Phiên bản hiệu lực:{" "}
            <strong>
              {doc.effectiveDate} ({doc.version})
            </strong>{" "}
            · Cập nhật bởi {doc.updatedBy}
          </p>
          {doc.summary && (
            <p className="mt-3 text-sm italic text-muted/90 bg-white p-3 rounded-xl border border-border">
              {doc.summary}
            </p>
          )}
        </div>

        <article className="mt-8 space-y-8 text-sm leading-relaxed text-ink/90">
          {doc.sections.map((sec) => (
            <section key={sec.id} className="space-y-3">
              <h2 className="text-lg font-bold text-ink">{sec.title}</h2>
              <div className="whitespace-pre-line text-ink/80 text-sm leading-relaxed bg-white/50 p-4 rounded-xl border border-border/60">
                {sec.content}
              </div>
            </section>
          ))}
        </article>

        {/* Navigation bottom */}
        <div className="mt-12 flex flex-wrap items-center justify-between gap-4 border-t border-border pt-6 text-xs text-muted">
          <Link
            href="/terms"
            className="inline-flex items-center gap-1 text-brand font-medium hover:underline"
          >
            ← Xem Điều khoản & Điều kiện sử dụng
          </Link>
          <Link
            href="/support"
            className="inline-flex items-center gap-1 text-brand font-medium hover:underline"
          >
            Trung tâm hỗ trợ khách hàng →
          </Link>
        </div>
      </main>
    </div>
  );
}
