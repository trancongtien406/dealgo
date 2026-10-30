"use client";

import { focusRing } from "@/components/ui/admin-list-ui";
import type { PartnerDocument } from "@/features/kyc/partner-review";
import {
  pickIdentityTriple,
  type KycCheckRow,
  type KycCheckTone,
  type KycReviewChecks,
} from "@/features/kyc/review-checks";

const toneClass: Record<KycCheckTone, string> = {
  ok: "text-success",
  warn: "text-danger",
  muted: "text-muted",
};

/** t52u: CCCD front, back and face side by side so ops compares the person to the card. */
export function KycIdentityCompare({
  documents,
}: {
  documents: PartnerDocument[];
}) {
  const { front, back, face, clip } = pickIdentityTriple(documents);
  if (!front && !back && !face) {
    return null;
  }
  const cells: Array<[string, PartnerDocument | null]> = [
    ["Mặt trước", front],
    ["Mặt sau", back],
    ["Khuôn mặt", face],
  ];
  return (
    <>
      <ul
        className="mt-3 grid grid-cols-3 gap-2"
        aria-label="So sánh CCCD và khuôn mặt"
      >
        {cells.map(([label, doc]) => (
          <li
            key={label}
            className="overflow-hidden rounded-xl border border-border bg-white"
          >
            <div className="flex aspect-[3/4] items-center justify-center bg-canvas/60">
              {doc?.url && doc.isImage ? (
                <a
                  href={doc.url}
                  target="_blank"
                  rel="noreferrer"
                  className={`block size-full ${focusRing}`}
                  aria-label={`Mở ${doc.label}`}
                >
                  {/* eslint-disable-next-line @next/next/no-img-element -- same-origin BFF stream */}
                  <img
                    src={doc.url}
                    alt={doc.label}
                    className="size-full object-contain"
                  />
                </a>
              ) : (
                <span className="px-2 text-center text-xs text-muted">
                  Chưa có ảnh
                </span>
              )}
            </div>
            <p className="px-2 py-1.5 text-center text-xs font-medium text-ink">
              {label}
            </p>
          </li>
        ))}
      </ul>
      {clip?.url && clip.isVideo ? (
        <figure className="mt-2 overflow-hidden rounded-xl border border-border bg-white">
          <video
            src={clip.url}
            controls
            muted
            playsInline
            preload="metadata"
            className="max-h-80 w-full bg-black"
            aria-label="Video khuôn mặt (liveness)"
          />
          <figcaption className="px-2 py-1.5 text-center text-xs font-medium text-ink">
            Video liveness (app tự quay) — đối chiếu với ảnh CCCD
          </figcaption>
        </figure>
      ) : null}
    </>
  );
}

function CheckList({ rows }: { rows: KycCheckRow[] }) {
  return (
    <dl className="mt-2 space-y-1 text-sm">
      {rows.map((row) => (
        <div key={row.label} className="flex justify-between gap-3">
          <dt className="text-muted">{row.label}</dt>
          <dd className={`font-medium ${toneClass[row.tone]}`}>{row.value}</dd>
        </div>
      ))}
    </dl>
  );
}

/** t52u: advisory checks. Never a decision — ops still approves/rejects by hand. */
export function KycChecksPanel({ checks }: { checks: KycReviewChecks }) {
  return (
    <div className="mt-3 space-y-3">
      <div className="rounded-xl border border-border px-3 py-2">
        <p className="text-xs font-semibold uppercase text-muted">
          Thiết bị báo (app đối tác)
        </p>
        {checks.device.length > 0 ? (
          <CheckList rows={checks.device} />
        ) : (
          <p className="mt-1 text-sm text-muted">
            Không có dữ liệu chụp thông minh.
          </p>
        )}
      </div>
      <p className="text-xs text-muted">
        Chỉ là dữ liệu chụp ảnh để tham khảo — nhân viên duyệt thủ công.
      </p>
    </div>
  );
}
