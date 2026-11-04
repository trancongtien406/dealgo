"use client";

import { useState } from "react";
import Link from "next/link";
import { OpsIcon } from "@/components/ui/ops-icons";
import { PublicPageHeader } from "@/features/content-cms/components/public-page-header";
import type { PublicPageLocale } from "@/features/content-cms/types";
import {
  ACCOUNT_DELETION_ROLES,
  accountDeletionCopy,
  type AccountDeletionRole,
} from "@/features/account-deletion/copy";

const fieldClass =
  "mt-1.5 h-10 w-full rounded-xl border border-border bg-white px-3 text-sm text-ink focus:border-brand focus:outline-none";
const labelClass = "block text-xs font-medium text-muted";

type Props = {
  locale: PublicPageLocale;
  contactEmail?: string;
  hotline?: string;
};

/** Public web deletion resource required by Google Play (Data deletion → account deletion URL). */
export function AccountDeletionClient({
  locale,
  contactEmail,
  hotline,
}: Props) {
  const t = accountDeletionCopy(locale);
  const q = locale === "en" ? "?lang=en" : "";

  const [role, setRole] = useState<AccountDeletionRole>("CUSTOMER");
  const [contact, setContact] = useState("");
  const [name, setName] = useState("");
  const [note, setNote] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [ticketCode, setTicketCode] = useState<string | null>(null);

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    const trimmedContact = contact.trim();
    if (trimmedContact.length < 5) {
      setError(t.form.invalidContact);
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      const res = await fetch("/api/public/support", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          role,
          category: "ACCOUNT",
          contact: trimmedContact,
          contactName: name.trim() || undefined,
          content: note.trim()
            ? `${t.ticketPrefix} ${note.trim()}`
            : t.ticketPrefix,
        }),
      });
      const json = (await res.json().catch(() => null)) as {
        success?: boolean;
        message?: string;
        data?: { ticketCode?: string };
      } | null;
      if (!res.ok || !json?.success || !json.data?.ticketCode) {
        setError(
          locale === "vi" && json?.message ? json.message : t.form.error,
        );
        return;
      }
      setTicketCode(json.data.ticketCode);
    } catch {
      setError(t.form.offline);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="min-h-screen bg-canvas text-ink" lang={locale}>
      <PublicPageHeader path="/account-deletion" locale={locale} />

      <section className="border-b border-border bg-gradient-to-b from-brand/5 via-white to-canvas px-4 py-12 sm:px-6 sm:py-16">
        <div className="mx-auto max-w-3xl">
          <div className="inline-flex items-center gap-2 rounded-full bg-success/10 px-3 py-1 text-xs font-medium text-success">
            <OpsIcon name="shield" className="size-3.5" />
            {t.badge}
          </div>
          <h1 className="mt-4 text-3xl font-extrabold tracking-tight text-ink sm:text-4xl">
            {t.title}
          </h1>
          <p className="mt-3 text-sm leading-relaxed text-muted">{t.intro}</p>
        </div>
      </section>

      <main className="mx-auto max-w-4xl space-y-8 px-4 py-10 sm:px-6 sm:py-12">
        <section className="rounded-2xl border border-border bg-white p-5 sm:p-6">
          <div className="flex items-center gap-3">
            <span className="grid size-10 place-items-center rounded-xl bg-canvas text-ink">
              <OpsIcon name="user" className="size-5" />
            </span>
            <h2 className="text-lg font-bold text-ink">{t.inAppTitle}</h2>
          </div>
          <ol className="mt-4 space-y-2.5">
            {t.inAppSteps.map((step, index) => (
              <li
                key={step}
                className="flex items-start gap-3 text-sm text-ink/80"
              >
                <span className="mt-0.5 grid size-5 shrink-0 place-items-center rounded-full bg-brand/10 text-[11px] font-bold text-brand">
                  {index + 1}
                </span>
                <span>{step}</span>
              </li>
            ))}
          </ol>
          <p className="mt-4 rounded-xl border border-border/60 bg-canvas/60 p-3 text-xs leading-relaxed text-muted">
            {t.inAppNote}
          </p>
        </section>

        <section
          id="request-form"
          className="rounded-2xl border border-border bg-white p-5 sm:p-6"
        >
          <div className="flex items-center gap-3">
            <span className="grid size-10 place-items-center rounded-xl bg-canvas text-ink">
              <OpsIcon name="mail" className="size-5" />
            </span>
            <div>
              <h2 className="text-lg font-bold text-ink">{t.webTitle}</h2>
              <p className="mt-1 text-xs leading-relaxed text-muted">
                {t.webIntro}
              </p>
            </div>
          </div>

          {ticketCode ? (
            <div className="mt-6 space-y-4 rounded-2xl border border-success/30 bg-success/5 p-6 text-center">
              <span className="mx-auto grid size-12 place-items-center rounded-full bg-success/20 text-success">
                <OpsIcon name="check" className="size-6" />
              </span>
              <h3 className="text-base font-bold text-ink">
                {t.form.doneTitle}
              </h3>
              <p className="text-sm text-muted">{t.form.doneBody}</p>
              <div className="inline-flex items-center gap-2 rounded-xl border border-border bg-white px-4 py-2">
                <span className="text-xs text-muted">{t.form.code}:</span>
                <span className="font-mono text-base font-bold tracking-wider text-brand">
                  {ticketCode}
                </span>
              </div>
              <div>
                <button
                  type="button"
                  onClick={() => {
                    setTicketCode(null);
                    setContact("");
                    setName("");
                    setNote("");
                  }}
                  className="inline-flex h-10 items-center rounded-xl px-3 text-xs font-medium text-muted hover:text-ink"
                >
                  {t.form.another}
                </button>
              </div>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="mt-5 space-y-4">
              {error ? (
                <div
                  role="alert"
                  className="flex items-center gap-2 rounded-xl border border-danger/30 bg-danger/5 p-3 text-xs text-danger"
                >
                  <OpsIcon name="alert" className="size-4 shrink-0" />
                  <span>{error}</span>
                </div>
              ) : null}
              <div className="grid gap-4 sm:grid-cols-2">
                <div>
                  <label htmlFor="del-role" className={labelClass}>
                    {t.form.role}
                  </label>
                  <select
                    id="del-role"
                    value={role}
                    onChange={(e) =>
                      setRole(e.target.value as AccountDeletionRole)
                    }
                    className={fieldClass}
                  >
                    {ACCOUNT_DELETION_ROLES.map((key) => (
                      <option key={key} value={key}>
                        {t.form.roles[key]}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label htmlFor="del-name" className={labelClass}>
                    {t.form.name}
                  </label>
                  <input
                    id="del-name"
                    maxLength={80}
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    className={fieldClass}
                  />
                </div>
              </div>
              <div>
                <label htmlFor="del-contact" className={labelClass}>
                  {t.form.contact} <span className="text-danger">*</span>
                </label>
                <input
                  id="del-contact"
                  required
                  minLength={5}
                  maxLength={120}
                  autoComplete="email"
                  value={contact}
                  onChange={(e) => setContact(e.target.value)}
                  className={fieldClass}
                  aria-describedby="del-contact-hint"
                />
                <p
                  id="del-contact-hint"
                  className="mt-1.5 text-[11px] text-muted"
                >
                  {t.form.contactHint}
                </p>
              </div>
              <div>
                <label htmlFor="del-note" className={labelClass}>
                  {t.form.note}
                </label>
                <textarea
                  id="del-note"
                  rows={3}
                  maxLength={1000}
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                  placeholder={t.form.notePlaceholder}
                  className="mt-1.5 w-full rounded-xl border border-border bg-white p-3 text-sm text-ink placeholder:text-muted focus:border-brand focus:outline-none"
                />
              </div>
              <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                <p className="text-[11px] leading-relaxed text-muted">
                  {t.form.privacy}{" "}
                  <Link
                    href={`/privacy${q}`}
                    className="font-medium text-brand hover:underline"
                  >
                    {t.privacyLink}
                  </Link>
                </p>
                <button
                  type="submit"
                  disabled={submitting}
                  className="inline-flex h-11 items-center justify-center rounded-xl bg-brand px-5 text-sm font-semibold text-white hover:bg-brand/90 disabled:opacity-50"
                >
                  {submitting ? t.form.sending : t.form.submit}
                </button>
              </div>
            </form>
          )}
        </section>

        <div className="grid gap-4 md:grid-cols-2">
          <section className="rounded-2xl border border-border bg-white p-5">
            <div className="flex items-center gap-2">
              <OpsIcon name="close" className="size-4 text-danger" />
              <h2 className="text-base font-bold text-ink">{t.dataTitle}</h2>
            </div>
            <ul className="mt-3 space-y-2">
              {t.dataItems.map((item) => (
                <li
                  key={item}
                  className="flex items-start gap-2 text-sm leading-relaxed text-ink/80"
                >
                  <span className="mt-2 size-1.5 shrink-0 rounded-full bg-danger/60" />
                  <span>{item}</span>
                </li>
              ))}
            </ul>
          </section>
          <section className="rounded-2xl border border-border bg-white p-5">
            <div className="flex items-center gap-2">
              <OpsIcon name="receipt" className="size-4 text-muted" />
              <h2 className="text-base font-bold text-ink">{t.keepTitle}</h2>
            </div>
            <ul className="mt-3 space-y-2">
              {t.keepItems.map((item) => (
                <li
                  key={item}
                  className="flex items-start gap-2 text-sm leading-relaxed text-ink/80"
                >
                  <span className="mt-2 size-1.5 shrink-0 rounded-full bg-muted/60" />
                  <span>{item}</span>
                </li>
              ))}
            </ul>
          </section>
        </div>

        <div className="grid gap-4 md:grid-cols-2">
          <section className="rounded-2xl border border-border bg-white p-5">
            <div className="flex items-center gap-2">
              <OpsIcon name="clock" className="size-4 text-muted" />
              <h2 className="text-base font-bold text-ink">{t.timingTitle}</h2>
            </div>
            <ul className="mt-3 space-y-2">
              {t.timingItems.map((item) => (
                <li
                  key={item}
                  className="flex items-start gap-2 text-sm leading-relaxed text-ink/80"
                >
                  <span className="mt-2 size-1.5 shrink-0 rounded-full bg-brand/50" />
                  <span>{item}</span>
                </li>
              ))}
            </ul>
          </section>
          <section className="rounded-2xl border border-border bg-white p-5">
            <div className="flex items-center gap-2">
              <OpsIcon name="lock" className="size-4 text-muted" />
              <h2 className="text-base font-bold text-ink">
                {t.blockersTitle}
              </h2>
            </div>
            <ul className="mt-3 space-y-2">
              {t.blockersItems.map((item) => (
                <li
                  key={item}
                  className="flex items-start gap-2 text-sm leading-relaxed text-ink/80"
                >
                  <span className="mt-2 size-1.5 shrink-0 rounded-full bg-muted/60" />
                  <span>{item}</span>
                </li>
              ))}
            </ul>
          </section>
        </div>

        <section className="rounded-2xl border border-border bg-white p-5">
          <h2 className="text-base font-bold text-ink">{t.cancelTitle}</h2>
          <p className="mt-2 text-sm leading-relaxed text-ink/80">
            {t.cancelBody}
          </p>
        </section>

        <section className="rounded-2xl border border-border bg-white p-5">
          <h2 className="text-base font-bold text-ink">{t.contactTitle}</h2>
          <p className="mt-2 text-sm leading-relaxed text-ink/80">
            {t.contactBody}
          </p>
          <div className="mt-4 flex flex-wrap gap-3 text-sm">
            {hotline ? (
              <a
                href={`tel:${hotline.replace(/[^0-9+]/g, "")}`}
                className="inline-flex h-10 items-center gap-2 rounded-xl border border-border px-4 font-semibold text-ink hover:border-brand hover:text-brand"
              >
                <OpsIcon name="phone" className="size-4 text-muted" />
                {hotline}
              </a>
            ) : null}
            {contactEmail ? (
              <a
                href={`mailto:${contactEmail}?subject=${encodeURIComponent(t.ticketPrefix)}`}
                className="inline-flex h-10 items-center gap-2 rounded-xl border border-border px-4 font-semibold text-ink hover:border-brand hover:text-brand"
              >
                <OpsIcon name="mail" className="size-4 text-muted" />
                {contactEmail}
              </a>
            ) : null}
            <Link
              href={`/support${q}`}
              className="inline-flex h-10 items-center gap-2 rounded-xl border border-border px-4 font-semibold text-ink hover:border-brand hover:text-brand"
            >
              <OpsIcon name="headset" className="size-4 text-muted" />
              {t.support}
            </Link>
          </div>
        </section>

        <div className="flex flex-wrap items-center justify-center gap-3 border-t border-border pt-6 text-xs">
          <Link
            href={`/terms${q}`}
            className="font-medium text-brand hover:underline"
          >
            {t.termsLink}
          </Link>
          <span className="text-muted">·</span>
          <Link
            href={`/privacy${q}`}
            className="font-medium text-brand hover:underline"
          >
            {t.privacyLink}
          </Link>
          <span className="text-muted">·</span>
          <Link
            href={`/regulations${q}`}
            className="font-medium text-brand hover:underline"
          >
            {t.regulationsLink}
          </Link>
        </div>
      </main>
    </div>
  );
}
