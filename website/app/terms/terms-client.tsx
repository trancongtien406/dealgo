"use client";

import Link from "next/link";
import { BrandMark } from "@/components/layout/brand-mark";
import { OpsIcon } from "@/components/ui/ops-icons";
import { useCmsDocumentQuery } from "@/features/content-cms/hooks";

export function TermsClient() {
  const { data: doc, isPending } = useCmsDocumentQuery("TERMS");

  if (isPending || !doc) {
    return (
      <div className="min-h-screen bg-canvas text-ink flex flex-col items-center justify-center p-4">
        <OpsIcon
          name="refresh"
          className="size-8 animate-spin text-brand mb-3"
        />
        <p className="text-sm font-medium text-muted">
          Đang tải điều khoản sử dụng từ máy chủ DealGo...
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
          <div className="inline-flex items-center gap-2 rounded-full bg-brand/10 px-3 py-1 text-xs font-medium text-brand">
            <OpsIcon name="shield" className="size-3.5" />
            {doc.badge || "Văn bản pháp lý nền tảng DealGo"}
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

        {/* Footer info box */}
        <div className="mt-12 rounded-2xl border border-border bg-white p-6 shadow-xs">
          <h3 className="font-semibold text-ink">
            Cần giải đáp về Điều khoản & Điều kiện?
          </h3>
          <p className="mt-1 text-xs text-muted">
            Đội ngũ Pháp chế và Hỗ trợ khách hàng của DealGo sẵn sàng tiếp nhận
            ý kiến đóng góp và thắc mắc của bạn.
          </p>
          <div className="mt-4 flex flex-wrap gap-3">
            <Link
              href="/support"
              className="inline-flex h-9 items-center gap-1.5 rounded-xl bg-brand px-4 text-xs font-medium text-white hover:bg-brand/90 transition-colors"
            >
              <OpsIcon name="headset" className="size-3.5" />
              Gửi yêu cầu hỗ trợ
            </Link>
            <Link
              href="/privacy"
              className="inline-flex h-9 items-center gap-1.5 rounded-xl border border-border bg-white px-4 text-xs font-medium text-ink hover:bg-canvas transition-colors"
            >
              <OpsIcon name="shield" className="size-3.5 text-muted" />
              Xem Chính sách Quyền riêng tư
            </Link>
          </div>
        </div>
      </main>
    </div>
  );
}
