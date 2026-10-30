import type { OcrField } from "@/features/kyc/ocr-fields";

const SOURCE_BADGE: Record<OcrField["source"], { text: string; className: string }> = {
  OCR: { text: "Đọc từ ảnh", className: "border-success/30 bg-success/5 text-success" },
  EDITED: { text: "Đã sửa tay", className: "border-food/40 bg-food/10 text-ink" },
  MANUAL: { text: "Nhập tay", className: "border-border bg-canvas text-muted" },
};

/** t61u: on-device OCR values beside the document images, with their source. */
export function KycOcrFieldsPanel({
  fields,
  autoApproved,
  autoApproveSkipped,
}: {
  fields: OcrField[];
  autoApproved: boolean;
  autoApproveSkipped: string[];
}) {
  return (
    <section
      className="rounded-2xl border border-border bg-white p-4 shadow-sm"
      data-testid="kyc-ocr-fields"
    >
      <h3 className="text-sm font-semibold text-ink">Thông tin đọc từ giấy tờ</h3>
      {autoApproved ? (
        <p className="mt-2 rounded-xl border border-success/30 bg-success/5 px-3 py-2 text-xs text-ink">
          Hệ thống đã tự động duyệt (đủ giấy tờ và thông tin hợp lệ).
        </p>
      ) : null}
      {autoApproveSkipped.length > 0 ? (
        <p className="mt-2 rounded-xl border border-food/30 bg-food/5 px-3 py-2 text-xs text-ink">
          Không tự động duyệt: {autoApproveSkipped.join(" · ")}
        </p>
      ) : null}
      {fields.length === 0 ? (
        <p className="mt-3 text-sm text-muted">Hồ sơ chưa có thông tin đọc từ ảnh.</p>
      ) : (
        <dl className="mt-3 space-y-2 text-sm">
          {fields.map((field) => (
            <div
              key={field.key}
              className="flex items-center justify-between gap-3 rounded-xl border border-border px-3 py-2"
            >
              <dt className="text-muted">{field.label}</dt>
              <dd className="flex items-center gap-2 text-right font-medium text-ink">
                <span>{field.value}</span>
                <span
                  className={`rounded-full border px-2 py-0.5 text-[11px] font-medium ${SOURCE_BADGE[field.source].className}`}
                >
                  {SOURCE_BADGE[field.source].text}
                </span>
              </dd>
            </div>
          ))}
        </dl>
      )}
    </section>
  );
}
