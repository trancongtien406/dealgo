"use client";

import { focusRing } from "@/components/ui/admin-list-ui";
import type { NestPartnerRole } from "@/features/kyc/nest-types";
import {
  PARTNER_ISSUE_SECTIONS,
  issueSectionLabel,
  type PartnerDocument,
  type PartnerIssue,
} from "@/features/kyc/partner-review";

/** Uploaded KYC/KYB documents with inline previews served by the BFF. */
export function PartnerDocumentsPanel({
  documents,
}: {
  documents: PartnerDocument[];
}) {
  if (documents.length === 0) {
    return (
      <p className="mt-3 rounded-xl border border-dashed border-border bg-canvas/40 px-3 py-8 text-center text-sm text-muted">
        Hồ sơ chưa có giấy tờ tải lên.
      </p>
    );
  }
  return (
    <ul className="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-2">
      {documents.map((doc) => (
        <li
          key={doc.index}
          className="overflow-hidden rounded-xl border border-border bg-white"
        >
          <div className="flex aspect-[4/3] items-center justify-center bg-canvas/60">
            {doc.url && doc.isImage ? (
              <a
                href={doc.url}
                target="_blank"
                rel="noreferrer"
                className={`block size-full ${focusRing}`}
                aria-label={`Mở ${doc.label}`}
              >
                {/* eslint-disable-next-line @next/next/no-img-element -- same-origin BFF stream, no optimisation wanted */}
                <img
                  src={doc.url}
                  alt={doc.label}
                  loading="lazy"
                  className="size-full object-contain"
                />
              </a>
            ) : doc.url ? (
              <a
                href={doc.url}
                target="_blank"
                rel="noreferrer"
                className={`rounded-lg border border-brand/30 px-3 py-2 text-sm font-medium text-brand ${focusRing}`}
              >
                Mở tệp PDF
              </a>
            ) : (
              <span className="px-3 text-center text-xs text-muted">
                Không có tệp (dữ liệu mẫu)
              </span>
            )}
          </div>
          <div className="space-y-0.5 px-3 py-2">
            <p className="text-sm font-medium text-ink">{doc.label}</p>
            <p className="text-xs text-muted">
              {doc.sizeLabel} · {doc.uploadedAt || "—"}
            </p>
          </div>
        </li>
      ))}
    </ul>
  );
}

/** Checklist of sections to send back for correction, each with a note. */
export function PartnerIssuePicker({
  role,
  value,
  onChange,
  disabled,
}: {
  role: NestPartnerRole;
  value: PartnerIssue[];
  onChange: (next: PartnerIssue[]) => void;
  disabled?: boolean;
}) {
  const toggle = (section: string, checked: boolean) => {
    onChange(
      checked
        ? [...value, { section, note: "" }]
        : value.filter((issue) => issue.section !== section),
    );
  };
  const setNote = (section: string, note: string) => {
    onChange(
      value.map((issue) =>
        issue.section === section ? { ...issue, note } : issue,
      ),
    );
  };
  return (
    <fieldset className="mt-3 space-y-2" disabled={disabled}>
      <legend className="text-xs font-medium text-muted">
        Mục đối tác cần bổ sung
      </legend>
      {PARTNER_ISSUE_SECTIONS[role].map((section) => {
        const current = value.find((issue) => issue.section === section.value);
        const id = `issue-${section.value}`;
        return (
          <div
            key={section.value}
            className="rounded-xl border border-border px-3 py-2"
          >
            <label
              htmlFor={id}
              className="flex items-center gap-2 text-sm text-ink"
            >
              <input
                id={id}
                type="checkbox"
                checked={Boolean(current)}
                onChange={(event) =>
                  toggle(section.value, event.target.checked)
                }
                className="size-4 accent-brand"
              />
              {section.label}
            </label>
            {current ? (
              <input
                type="text"
                aria-label={`Ghi chú: ${section.label}`}
                value={current.note}
                maxLength={300}
                onChange={(event) => setNote(section.value, event.target.value)}
                placeholder="Ví dụ: ảnh bị mờ, chụp lại đủ 4 góc"
                className={`mt-2 w-full rounded-lg border border-border px-2 py-1.5 text-sm ${focusRing}`}
              />
            ) : null}
          </div>
        );
      })}
    </fieldset>
  );
}

/** Server-side review result (reason + per-section issues) for decided applications. */
export function PartnerReviewOutcome({
  role,
  reason,
  issues,
}: {
  role: NestPartnerRole;
  reason: string | null;
  issues: PartnerIssue[];
}) {
  if (!reason && issues.length === 0) {
    return null;
  }
  return (
    <div className="mt-3 rounded-xl border border-danger/30 bg-danger/5 px-3 py-2 text-sm text-ink">
      {reason ? <p className="font-medium">Lý do: {reason}</p> : null}
      {issues.length > 0 ? (
        <ul className="mt-1 list-disc space-y-0.5 pl-5">
          {issues.map((issue) => (
            <li key={issue.section}>
              <span className="font-medium">
                {issueSectionLabel(role, issue.section)}:
              </span>{" "}
              {issue.note}
            </li>
          ))}
        </ul>
      ) : null}
    </div>
  );
}
