"use client";

import { useState } from "react";
import Link from "next/link";
import { OpsIcon, type OpsIconName } from "@/components/ui/ops-icons";
import { shownContact } from "@/features/content-cms/public-documents";
import { PublicPageHeader } from "@/features/content-cms/components/public-page-header";
import type { PublicPageView, SupportCategory, SupportContent } from "@/features/content-cms/types";

const COPY = {
  vi: {
    heading: "Chúng tôi có thể giúp gì cho bạn?",
    search: "Tìm vấn đề",
    topics: "Chủ đề hỗ trợ",
    sendForTopic: "Gửi yêu cầu →",
    formTitle: "Gửi yêu cầu hỗ trợ",
    role: "Bạn là",
    roles: { CUSTOMER: "Khách hàng", DRIVER: "Tài xế", MERCHANT: "Cửa hàng", OTHER: "Khác" },
    topic: "Nhóm vấn đề",
    topicsList: { PAYMENT: "Thanh toán", RIDE: "Chuyến đi", FOOD: "Đơn đồ ăn", ACCOUNT: "Tài khoản", SAFETY: "An toàn", OTHER: "Khác" },
    contact: "Số điện thoại hoặc email",
    name: "Tên",
    ref: "Mã chuyến / đơn",
    content: "Nội dung",
    submit: "Gửi yêu cầu",
    sending: "Đang gửi…",
    failed: "Không thể gửi yêu cầu. Thử lại.",
    offline: "Mất kết nối máy chủ. Thử lại.",
    done: "Đã tạo yêu cầu hỗ trợ",
    code: "Mã yêu cầu",
    another: "Gửi yêu cầu khác",
    hotline: "Hotline",
    email: "Email",
    hours: "Giờ hỗ trợ",
    address: "Địa chỉ",
    terms: "Điều khoản",
    privacy: "Quyền riêng tư",
    messenger: "Chat với DealGo qua Messenger",
  },
  en: {
    heading: "How can we help?",
    search: "Search issues",
    topics: "Help topics",
    sendForTopic: "Send a request →",
    formTitle: "Send a support request",
    role: "You are",
    roles: { CUSTOMER: "Customer", DRIVER: "Driver", MERCHANT: "Merchant", OTHER: "Other" },
    topic: "Topic",
    topicsList: { PAYMENT: "Payment", RIDE: "Ride", FOOD: "Food order", ACCOUNT: "Account", SAFETY: "Safety", OTHER: "Other" },
    contact: "Phone or email",
    name: "Name",
    ref: "Ride / order code",
    content: "Message",
    submit: "Send request",
    sending: "Sending…",
    failed: "Could not send the request. Try again.",
    offline: "Connection lost. Try again.",
    done: "Support request created",
    code: "Request code",
    another: "Send another request",
    hotline: "Hotline",
    email: "Email",
    hours: "Hours",
    address: "Address",
    terms: "Terms",
    privacy: "Privacy",
    messenger: "Chat with DealGo on Messenger",
  },
} as const;

const ICONS = new Set<OpsIconName>(["motorcycle", "utensils", "user", "driver", "store", "car", "wallet", "shield", "headset", "package", "receipt", "users"]);
const TONE_CLASS: Record<string, string> = {
  ride: "border-brand/20 bg-brand/10 text-brand",
  food: "border-food/20 bg-food/10 text-food",
  delivery: "border-delivery/20 bg-delivery/10 text-delivery",
  neutral: "border-border bg-canvas text-ink",
};

const fieldClass =
  "mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink focus:border-brand focus:outline-none";
const labelClass = "block text-xs font-medium text-muted";

export function SupportClient({ page, messengerUrl }: { page: PublicPageView<SupportContent>; messengerUrl?: string }) {
  const t = COPY[page.locale];
  const config = page.content;
  const hotline = shownContact(config.hotline);
  const email = shownContact(config.email);
  const hours = shownContact(config.hours);
  const address = shownContact(config.address);
  const q = page.locale === "en" ? "?lang=en" : "";

  const [query, setQuery] = useState("");
  const [role, setRole] = useState<string>("CUSTOMER");
  const [topic, setTopic] = useState<string>("PAYMENT");
  const [contactName, setContactName] = useState("");
  const [refCode, setRefCode] = useState("");
  const [contact, setContact] = useState("");
  const [content, setContent] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [ticketCode, setTicketCode] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!content.trim() || !contact.trim()) return;
    setSubmitting(true);
    setSubmitError(null);
    try {
      const res = await fetch("/api/public/support", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          role,
          category: topic,
          refCode: refCode.trim() || undefined,
          contact: contact.trim(),
          contactName: contactName.trim() || undefined,
          content: content.trim(),
        }),
      });
      const json = (await res.json().catch(() => null)) as {
        success?: boolean;
        message?: string;
        data?: { ticketCode?: string };
      } | null;
      if (!res.ok || !json?.success || !json.data?.ticketCode) {
        setSubmitError(json?.message || t.failed);
        return;
      }
      setTicketCode(json.data.ticketCode);
    } catch {
      setSubmitError(t.offline);
    } finally {
      setSubmitting(false);
    }
  };

  const needle = query.trim().toLowerCase();
  const categories: SupportCategory[] = config.categories
    .map((cat) => (needle ? { ...cat, items: cat.items.filter((i) => i.toLowerCase().includes(needle)) } : cat))
    .filter((cat) => !needle || cat.items.length > 0);

  return (
    <div className="min-h-screen bg-canvas text-ink" lang={page.locale}>
      <PublicPageHeader path="/support" locale={page.locale} showSupportLink={false} />

      <section className="border-b border-border bg-gradient-to-b from-brand/5 via-white to-canvas px-4 py-12 text-center sm:px-6 sm:py-16">
        <div className="mx-auto max-w-3xl">
          {config.systemStatusNotice ? (
            <div className="inline-flex items-center gap-2 rounded-full border border-success/30 bg-success/10 px-3 py-1 text-xs font-medium text-success">
              <span className="size-2 rounded-full bg-success" />
              {config.systemStatusNotice}
            </div>
          ) : null}
          <h1 className="mt-4 text-3xl font-extrabold tracking-tight text-ink sm:text-4xl">{page.title || t.heading}</h1>
          {page.summary ? <p className="mt-2 text-sm text-muted">{page.summary}</p> : null}
          <div className="relative mx-auto mt-6 max-w-xl">
            <OpsIcon name="search" className="pointer-events-none absolute top-1/2 left-3.5 size-4.5 -translate-y-1/2 text-muted" />
            <input
              type="search"
              aria-label={t.search}
              placeholder={t.search}
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              className="h-12 w-full rounded-2xl border border-border bg-white pr-4 pl-11 text-sm text-ink shadow-sm placeholder:text-muted focus:border-brand focus:ring-2 focus:ring-brand/20 focus:outline-none"
            />
          </div>
          {messengerUrl ? (
            <div className="mt-5 flex flex-wrap items-center justify-center gap-3">
              <a
                href={messengerUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex h-11 items-center gap-2 rounded-xl bg-brand px-5 text-sm font-semibold text-white shadow-sm hover:bg-brand/90 focus:ring-2 focus:ring-brand/30 focus:outline-none"
              >
                <OpsIcon name="headset" className="size-4.5" />
                {t.messenger}
              </a>
              <a href="#ticket-form" className="inline-flex h-11 items-center rounded-xl border border-border bg-white px-5 text-sm font-semibold text-ink hover:border-brand hover:text-brand">
                {t.formTitle}
              </a>
            </div>
          ) : null}
        </div>
      </section>

      {categories.length > 0 ? (
        <section className="mx-auto max-w-6xl px-4 py-10 sm:px-6 sm:py-12">
          <h2 className="text-xl font-bold text-ink">{t.topics}</h2>
          <div className="mt-6 grid gap-6 md:grid-cols-3">
            {categories.map((cat) => (
              <div key={cat.id} className="flex flex-col justify-between rounded-2xl border border-border bg-white p-5">
                <div>
                  <div className="flex items-center gap-3">
                    <span className={`grid size-10 place-items-center rounded-xl border ${TONE_CLASS[cat.tone] ?? TONE_CLASS.neutral}`}>
                      <OpsIcon name={ICONS.has(cat.icon as OpsIconName) ? (cat.icon as OpsIconName) : "headset"} className="size-5" />
                    </span>
                    <h3 className="font-bold text-ink">{cat.title}</h3>
                  </div>
                  <ul className="mt-4 space-y-2.5">
                    {cat.items.map((item) => (
                      <li key={item} className="flex items-start gap-2 text-xs text-muted">
                        <OpsIcon name="chevron" className="mt-0.5 size-3.5 shrink-0 rotate-270 text-muted" />
                        <span>{item}</span>
                      </li>
                    ))}
                  </ul>
                </div>
                <div className="mt-6 border-t border-border pt-4">
                  <a href="#ticket-form" onClick={() => setRole(cat.role)} className="text-xs font-semibold text-brand hover:underline">
                    {t.sendForTopic}
                  </a>
                </div>
              </div>
            ))}
          </div>
        </section>
      ) : null}

      <section id="ticket-form" className="border-t border-border bg-white px-4 py-12 sm:px-6 sm:py-16">
        <div className="mx-auto max-w-2xl">
          <h2 className="text-center text-2xl font-bold text-ink">{t.formTitle}</h2>
          {ticketCode ? (
            <div className="mt-8 space-y-4 rounded-2xl border border-success/30 bg-success/5 p-6 text-center">
              <span className="mx-auto grid size-12 place-items-center rounded-full bg-success/20 text-success">
                <OpsIcon name="check" className="size-6" />
              </span>
              <h3 className="text-lg font-bold text-ink">{t.done}</h3>
              <div className="inline-flex items-center gap-2 rounded-xl border border-border bg-white px-4 py-2">
                <span className="text-xs text-muted">{t.code}:</span>
                <span className="font-mono text-base font-bold tracking-wider text-brand">{ticketCode}</span>
              </div>
              <div>
                <button
                  type="button"
                  onClick={() => {
                    setTicketCode(null);
                    setContent("");
                    setContact("");
                    setRefCode("");
                    setContactName("");
                  }}
                  className="inline-flex h-10 items-center rounded-xl px-3 text-xs font-medium text-muted hover:text-ink"
                >
                  {t.another}
                </button>
              </div>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="mt-8 space-y-4">
              {submitError ? (
                <div role="alert" className="flex items-center gap-2 rounded-xl border border-danger/30 bg-danger/5 p-3 text-xs text-danger">
                  <OpsIcon name="alert" className="size-4 shrink-0" />
                  <span>{submitError}</span>
                </div>
              ) : null}
              <div className="grid gap-4 sm:grid-cols-2">
                <div>
                  <label htmlFor="sup-role" className={labelClass}>{t.role}</label>
                  <select id="sup-role" value={role} onChange={(e) => setRole(e.target.value)} className={fieldClass}>
                    {Object.entries(t.roles).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                  </select>
                </div>
                <div>
                  <label htmlFor="sup-topic" className={labelClass}>{t.topic}</label>
                  <select id="sup-topic" value={topic} onChange={(e) => setTopic(e.target.value)} className={fieldClass}>
                    {Object.entries(t.topicsList).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                  </select>
                </div>
              </div>
              <div>
                <label htmlFor="sup-contact" className={labelClass}>{t.contact} <span className="text-danger">*</span></label>
                <input id="sup-contact" required maxLength={120} value={contact} onChange={(e) => setContact(e.target.value)} className={fieldClass} />
              </div>
              <div className="grid gap-4 sm:grid-cols-2">
                <div>
                  <label htmlFor="sup-name" className={labelClass}>{t.name}</label>
                  <input id="sup-name" maxLength={80} value={contactName} onChange={(e) => setContactName(e.target.value)} className={fieldClass} />
                </div>
                <div>
                  <label htmlFor="sup-ref" className={labelClass}>{t.ref}</label>
                  <input id="sup-ref" maxLength={64} value={refCode} onChange={(e) => setRefCode(e.target.value)} className={fieldClass} />
                </div>
              </div>
              <div>
                <label htmlFor="sup-desc" className={labelClass}>{t.content} <span className="text-danger">*</span></label>
                <textarea id="sup-desc" rows={4} required minLength={10} maxLength={2000} value={content}
                  onChange={(e) => setContent(e.target.value)}
                  className="mt-1.5 w-full rounded-xl border border-border bg-white p-3 text-sm text-ink focus:border-brand focus:outline-none" />
              </div>
              <button type="submit" disabled={submitting}
                className="inline-flex h-11 w-full items-center justify-center gap-2 rounded-xl bg-brand text-sm font-semibold text-white hover:bg-brand/90 disabled:opacity-50">
                {submitting ? t.sending : t.submit}
              </button>
            </form>
          )}
        </div>
      </section>

      <section className="mx-auto max-w-6xl px-4 py-12 sm:px-6">
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {hotline ? (
            <ContactCard icon="phone" label={t.hotline}>
              <a href={`tel:${hotline.replace(/\s+/g, "")}`} className="font-bold text-danger hover:underline">{hotline}</a>
            </ContactCard>
          ) : null}
          {email ? (
            <ContactCard icon="mail" label={t.email}>
              <a href={`mailto:${email}`} className="font-bold text-brand hover:underline">{email}</a>
            </ContactCard>
          ) : null}
          {hours ? <ContactCard icon="clock" label={t.hours}>{hours}</ContactCard> : null}
          {address ? <ContactCard icon="pin" label={t.address}>{address}</ContactCard> : null}
        </div>
        <div className="mt-6 flex items-center justify-center gap-3 text-xs">
          <Link href={`/terms${q}`} className="font-medium text-brand hover:underline">{t.terms}</Link>
          <span>·</span>
          <Link href={`/privacy${q}`} className="font-medium text-brand hover:underline">{t.privacy}</Link>
        </div>
      </section>
    </div>
  );
}

function ContactCard({ icon, label, children }: { icon: OpsIconName; label: string; children: React.ReactNode }) {
  return (
    <div className="rounded-2xl border border-border bg-white p-5 text-center">
      <span className="mx-auto grid size-10 place-items-center rounded-xl bg-canvas text-ink">
        <OpsIcon name={icon} className="size-5" />
      </span>
      <h4 className="mt-2 text-xs font-medium text-muted">{label}</h4>
      <div className="mt-1 text-sm text-ink">{children}</div>
    </div>
  );
}
