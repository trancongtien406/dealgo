"use client";

import { useState } from "react";
import {
  AdminBreadcrumb,
  focusRing,
  PreviewButton,
  PreviewTabs,
  StatusChip,
} from "@/components/ui/admin-list-ui";
import { AdminForbiddenState, AdminListErrorBanner } from "@/components/ui/admin-state-ui";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";
import { OpsIcon } from "@/components/ui/ops-icons";
import { ReasonDialog } from "@/components/ui/reason-dialog";
import { toast } from "@/components/ui/toast";
import { isForbiddenError } from "@/lib/api/errors";
import { formatOpsDate, formatOpsDateTime } from "@/lib/ops-time";
import { CONTENT_CMS_DEFAULT_TAB, CONTENT_CMS_TABS, CONTENT_CMS_TAB_SLUG, PUBLIC_PAGE_HREF } from "../constants";
import {
  useOpsPublicPageQuery,
  usePublicPageRevisionsQuery,
  usePublishPublicPageMutation,
  useResetPublicPageMutation,
  useSavePublicPageDraftMutation,
} from "../hooks";
import type {
  LegalContent,
  LegalSection,
  PublicPageDraft,
  PublicPageLocale,
  PublicPageSlug,
  SupportCategory,
  SupportContent,
} from "../types";

const LOCALE_TABS = ["Tiếng Việt", "English"] as const;
const LOCALE_OF: Record<string, PublicPageLocale> = { "Tiếng Việt": "vi", English: "en" };
const ROLE_LABEL: Record<SupportCategory["role"], string> = {
  CUSTOMER: "Khách hàng",
  DRIVER: "Tài xế",
  MERCHANT: "Cửa hàng",
};

const inputClass =
  "mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink focus:border-brand focus:outline-none";
const labelClass = "block text-xs font-medium text-muted";

/** DEC-PROD-055: edit draft → publish (new version, audited) for /terms, /privacy, /support. */
export function ContentCmsBoard() {
  const [tab, setTab] = useState<string>(CONTENT_CMS_DEFAULT_TAB);
  const [localeTab, setLocaleTab] = useState<string>(LOCALE_TABS[0]);
  const slug: PublicPageSlug = CONTENT_CMS_TAB_SLUG[tab as (typeof CONTENT_CMS_TABS)[number]];
  const locale = LOCALE_OF[localeTab] ?? "vi";
  return (
    <div className="space-y-5">
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Cài đặt & Nhật ký", href: "/settings" },
          { label: "Nội dung & pháp lý" },
        ]}
      />
      <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">Nội dung & pháp lý</h1>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <PreviewTabs label="Trang" current={tab} onChange={setTab} tabs={CONTENT_CMS_TABS} />
        <PreviewTabs label="Ngôn ngữ" current={localeTab} onChange={setLocaleTab} tabs={LOCALE_TABS} />
      </div>
      <PageEditor key={`${slug}:${locale}`} slug={slug} locale={locale} />
    </div>
  );
}

function PageEditor({ slug, locale }: { slug: PublicPageSlug; locale: PublicPageLocale }) {
  const query = useOpsPublicPageQuery(slug, locale);
  const save = useSavePublicPageDraftMutation(slug, locale);
  const publish = usePublishPublicPageMutation(slug, locale);
  const reset = useResetPublicPageMutation(slug, locale);
  const [edited, setEdited] = useState<PublicPageDraft | null>(null);
  const [confirmReset, setConfirmReset] = useState(false);
  const [publishOpen, setPublishOpen] = useState(false);
  const [showHistory, setShowHistory] = useState(false);
  const revisions = usePublicPageRevisionsQuery(slug, locale, showHistory);

  const page = query.data;
  const draft: PublicPageDraft | null =
    edited ??
    (page
      ? { title: page.title, summary: page.summary, effectiveAt: page.effectiveAt, content: page.content }
      : null);
  const dirty = edited !== null;
  const href = `${PUBLIC_PAGE_HREF[slug]}${locale === "en" ? "?lang=en" : ""}`;

  if (query.isError && isForbiddenError(query.error)) {
    return <AdminForbiddenState title="Không có quyền chỉnh sửa nội dung" description="Cần quyền content.write." />;
  }
  if (query.isError) {
    return <AdminListErrorBanner message="Không thể tải nội dung." onRetry={() => void query.refetch()} />;
  }
  if (!page || !draft) {
    return <div className="h-64 animate-pulse rounded-2xl border border-border bg-white" />;
  }

  const update = (patch: Partial<PublicPageDraft>) => setEdited({ ...draft, ...patch });

  const saveDraft = async () => {
    try {
      await save.mutateAsync(draft);
      setEdited(null);
      toast.success("Đã lưu nháp.");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Không thể lưu.");
    }
  };

  const doPublish = async (reason: string) => {
    if (dirty) {
      await save.mutateAsync(draft);
      setEdited(null);
    }
    const next = await publish.mutateAsync(reason);
    toast.success(`Đã xuất bản phiên bản ${next.version}.`);
  };

  const statusChip =
    page.version === 0 ? (
      <StatusChip tone="danger">Chưa xuất bản</StatusChip>
    ) : (
      <StatusChip tone="success">Phiên bản {page.version}</StatusChip>
    );

  return (
    <div className="space-y-5">
      <section className="space-y-4 rounded-2xl border border-border bg-white p-5 shadow-sm">
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-border pb-4">
          <div className="flex flex-wrap items-center gap-2">
            {statusChip}
            {page.hasDraft || dirty ? <StatusChip tone="food">Có thay đổi chưa xuất bản</StatusChip> : null}
            {page.publishedAt ? (
              <span className="text-xs text-muted">Xuất bản {formatOpsDateTime(page.publishedAt)}</span>
            ) : null}
          </div>
          <div className="flex flex-wrap gap-2">
            <a
              href={href}
              target="_blank"
              rel="noopener noreferrer"
              className={`inline-flex h-9 items-center gap-1.5 rounded-xl border border-border bg-white px-3 text-xs font-medium text-ink hover:bg-canvas ${focusRing}`}
            >
              <OpsIcon name="eye" className="size-4" />
              Xem trang
            </a>
            <PreviewButton onClick={() => setShowHistory((v) => !v)}>
              <OpsIcon name="clock" className="size-4" />
              Lịch sử
            </PreviewButton>
            <PreviewButton tone="danger" onClick={() => setConfirmReset(true)}>
              <OpsIcon name="undo" className="size-4" />
              Khôi phục mặc định
            </PreviewButton>
          </div>
        </div>

        <div className="grid gap-4 sm:grid-cols-3">
          <div className="sm:col-span-2">
            <label className={labelClass} htmlFor="cms-title">Tiêu đề</label>
            <input id="cms-title" className={`${inputClass} font-semibold`} value={draft.title} maxLength={200}
              onChange={(e) => update({ title: e.target.value })} />
          </div>
          <div>
            <label className={labelClass} htmlFor="cms-effective">Ngày hiệu lực</label>
            <input id="cms-effective" type="date" className={inputClass} value={draft.effectiveAt?.slice(0, 10) ?? ""}
              onChange={(e) => update({ effectiveAt: e.target.value || null })} />
          </div>
          <div className="sm:col-span-3">
            <label className={labelClass} htmlFor="cms-summary">Tóm tắt</label>
            <textarea id="cms-summary" rows={2} maxLength={500} value={draft.summary ?? ""}
              onChange={(e) => update({ summary: e.target.value })}
              className="mt-1.5 w-full rounded-xl border border-border bg-white p-3 text-sm text-ink focus:border-brand focus:outline-none" />
          </div>
        </div>
      </section>

      {slug === "support" ? (
        <SupportEditor value={draft.content as SupportContent} onChange={(content) => update({ content })} />
      ) : (
        <LegalEditor value={draft.content as LegalContent} onChange={(content) => update({ content })} />
      )}

      {showHistory ? (
        <section className="rounded-2xl border border-border bg-white p-5 shadow-sm">
          <h2 className="text-base font-bold text-ink">Lịch sử xuất bản</h2>
          {revisions.isPending ? (
            <div className="mt-3 h-16 animate-pulse rounded-xl bg-canvas" />
          ) : (revisions.data ?? []).length === 0 ? (
            <p className="mt-3 text-sm text-muted">Chưa có phiên bản.</p>
          ) : (
            <ul className="mt-3 divide-y divide-border text-sm">
              {(revisions.data ?? []).map((r) => (
                <li key={r.version} className="flex flex-wrap items-center justify-between gap-2 py-2">
                  <span className="font-medium text-ink">v{r.version} · {r.title}</span>
                  <span className="text-xs text-muted">
                    {r.effectiveAt ? `Hiệu lực ${formatOpsDate(r.effectiveAt)} · ` : ""}
                    {formatOpsDateTime(r.publishedAt)}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </section>
      ) : null}

      <div className="flex flex-wrap items-center justify-end gap-3 rounded-2xl border border-border bg-white p-4">
        <button type="button" disabled={!dirty || save.isPending} onClick={() => void saveDraft()}
          className={`inline-flex h-10 items-center rounded-xl border border-border bg-white px-5 text-sm font-medium text-ink hover:bg-canvas disabled:opacity-40 ${focusRing}`}>
          Lưu nháp
        </button>
        <button type="button" disabled={!dirty && !page.hasDraft && page.version > 0} onClick={() => setPublishOpen(true)}
          className={`inline-flex h-10 items-center rounded-xl bg-brand px-6 text-sm font-semibold text-white hover:bg-brand/90 disabled:opacity-40 ${focusRing}`}>
          Xuất bản
        </button>
      </div>

      <ReasonDialog
        open={publishOpen}
        title="Xuất bản phiên bản mới"
        description={`Trang ${href} sẽ hiển thị nội dung này.`}
        confirmLabel="Xuất bản"
        onClose={() => setPublishOpen(false)}
        onSubmit={doPublish}
      />
      <ConfirmDialog
        open={confirmReset}
        title="Khôi phục nội dung mặc định"
        description="Bản nháp sẽ được thay bằng nội dung mặc định. Trang công khai không đổi cho đến khi xuất bản."
        confirmLabel="Khôi phục"
        tone="danger"
        pending={reset.isPending}
        onClose={() => setConfirmReset(false)}
        onConfirm={async () => {
          try {
            await reset.mutateAsync();
            setEdited(null);
            setConfirmReset(false);
            toast.success("Đã khôi phục bản nháp mặc định.");
          } catch (err) {
            toast.error(err instanceof Error ? err.message : "Không thể khôi phục.");
          }
        }}
      />
    </div>
  );
}

function LegalEditor({ value, onChange }: { value: LegalContent; onChange: (v: LegalContent) => void }) {
  const sections = value.sections;
  const setSections = (next: LegalSection[]) => onChange({ ...value, sections: next });
  const move = (i: number, d: -1 | 1) => {
    const j = i + d;
    if (j < 0 || j >= sections.length) return;
    const next = [...sections];
    [next[i], next[j]] = [next[j], next[i]];
    setSections(next);
  };
  return (
    <section className="space-y-4 rounded-2xl border border-border bg-white p-5 shadow-sm">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div className="min-w-[240px] flex-1">
          <label className={labelClass} htmlFor="cms-badge">Nhãn</label>
          <input id="cms-badge" className={inputClass} maxLength={120} value={value.badge}
            onChange={(e) => onChange({ ...value, badge: e.target.value })} />
        </div>
        <button type="button"
          onClick={() => setSections([...sections, { id: `sec-${Date.now()}`, title: `${sections.length + 1}. `, content: "" }])}
          className={`inline-flex h-10 items-center gap-1.5 rounded-xl border border-brand/30 bg-brand/5 px-3 text-xs font-semibold text-brand hover:bg-brand/10 ${focusRing}`}>
          <OpsIcon name="plus" className="size-4" />
          Thêm mục
        </button>
      </div>
      <div className="space-y-4 divide-y divide-border">
        {sections.map((sec, idx) => (
          <div key={sec.id} className="space-y-2 pt-4 first:pt-0">
            <div className="flex items-center gap-2">
              <input aria-label="Tiêu đề mục" value={sec.title} maxLength={200}
                onChange={(e) => setSections(sections.map((s) => (s.id === sec.id ? { ...s, title: e.target.value } : s)))}
                className="w-full border-b border-border/80 bg-transparent text-sm font-bold text-ink focus:border-brand focus:outline-none" />
              <IconButton label="Lên" disabled={idx === 0} onClick={() => move(idx, -1)} icon="chevron" rotate />
              <IconButton label="Xuống" disabled={idx === sections.length - 1} onClick={() => move(idx, 1)} icon="chevron" />
              <IconButton label="Xoá mục" disabled={sections.length <= 1} danger
                onClick={() => setSections(sections.filter((s) => s.id !== sec.id))} icon="close" />
            </div>
            <textarea aria-label="Nội dung mục" rows={5} value={sec.content} maxLength={20000}
              onChange={(e) => setSections(sections.map((s) => (s.id === sec.id ? { ...s, content: e.target.value } : s)))}
              className="w-full rounded-xl border border-border bg-canvas/30 p-3 text-xs leading-relaxed text-ink focus:border-brand focus:bg-white focus:outline-none" />
          </div>
        ))}
      </div>
    </section>
  );
}

function SupportEditor({ value, onChange }: { value: SupportContent; onChange: (v: SupportContent) => void }) {
  const field = (key: "hotline" | "email" | "hours" | "address" | "systemStatusNotice", label: string, wide = false) => (
    <div className={wide ? "sm:col-span-2" : undefined}>
      <label className={labelClass} htmlFor={`cms-${key}`}>{label}</label>
      <input id={`cms-${key}`} className={inputClass} value={value[key]}
        onChange={(e) => onChange({ ...value, [key]: e.target.value })} />
    </div>
  );
  const setCat = (i: number, patch: Partial<SupportCategory>) =>
    onChange({ ...value, categories: value.categories.map((c, j) => (j === i ? { ...c, ...patch } : c)) });
  return (
    <>
      <section className="grid gap-4 rounded-2xl border border-border bg-white p-5 shadow-sm sm:grid-cols-2">
        {field("hotline", "Hotline")}
        {field("email", "Email hỗ trợ")}
        {field("hours", "Giờ hỗ trợ")}
        {field("systemStatusNotice", "Thông báo trạng thái")}
        {field("address", "Địa chỉ", true)}
      </section>
      <section className="space-y-4 rounded-2xl border border-border bg-white p-5 shadow-sm">
        <div className="flex items-center justify-between">
          <h2 className="text-base font-bold text-ink">Chủ đề hỗ trợ</h2>
          <button type="button"
            onClick={() => onChange({ ...value, categories: [...value.categories, { id: `cat-${Date.now()}`, title: "", role: "CUSTOMER", icon: "headset", tone: "neutral", items: [] }] })}
            className={`inline-flex h-9 items-center gap-1.5 rounded-xl border border-brand/30 bg-brand/5 px-3 text-xs font-semibold text-brand hover:bg-brand/10 ${focusRing}`}>
            <OpsIcon name="plus" className="size-4" />
            Thêm chủ đề
          </button>
        </div>
        <div className="grid gap-4 md:grid-cols-2">
          {value.categories.map((cat, i) => (
            <div key={cat.id} className="space-y-2 rounded-xl border border-border bg-canvas/30 p-4">
              <div className="flex items-center gap-2">
                <input aria-label="Tên chủ đề" value={cat.title} maxLength={120} onChange={(e) => setCat(i, { title: e.target.value })}
                  className="w-full border-b border-border/80 bg-transparent text-sm font-semibold text-ink focus:border-brand focus:outline-none" />
                <select aria-label="Đối tượng" value={cat.role} onChange={(e) => setCat(i, { role: e.target.value as SupportCategory["role"] })}
                  className="h-8 rounded-lg border border-border bg-white px-2 text-xs">
                  {Object.entries(ROLE_LABEL).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                </select>
                <IconButton label="Xoá chủ đề" danger icon="close"
                  onClick={() => onChange({ ...value, categories: value.categories.filter((_, j) => j !== i) })} />
              </div>
              <textarea aria-label="Vấn đề (mỗi dòng một mục)" rows={4} value={cat.items.join("\n")}
                onChange={(e) => setCat(i, { items: e.target.value.split("\n").filter((l) => l.trim()) })}
                className="w-full rounded-lg border border-border bg-white p-2 text-xs text-ink focus:border-brand focus:outline-none" />
            </div>
          ))}
        </div>
      </section>
    </>
  );
}

function IconButton(props: {
  label: string;
  icon: "chevron" | "close";
  onClick: () => void;
  disabled?: boolean;
  danger?: boolean;
  rotate?: boolean;
}) {
  return (
    <button type="button" title={props.label} aria-label={props.label} disabled={props.disabled} onClick={props.onClick}
      className={`grid size-8 shrink-0 place-items-center rounded-lg border border-border bg-white disabled:opacity-30 ${props.danger ? "text-danger hover:bg-danger/10" : "text-muted hover:bg-canvas"} ${focusRing}`}>
      <OpsIcon name={props.icon} className={`size-3.5 ${props.rotate ? "rotate-180" : ""}`} />
    </button>
  );
}
