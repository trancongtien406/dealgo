/**
 * t61u: document fields read on the phone (ML Kit, no server AI) and confirmed by the
 * applicant. The app sends flat metadata keys plus `ocrPrefilled` / `ocrEdited`
 * comma lists, so ops can see which values came from the scan and which were typed over.
 */
export type OcrFieldSource = "OCR" | "EDITED" | "MANUAL";

export type OcrField = {
  key: string;
  label: string;
  value: string;
  source: OcrFieldSource;
};

export const OCR_FIELD_LABELS: ReadonlyArray<[string, string]> = [
  ["idNumber", "Số CCCD"],
  ["fullName", "Họ và tên"],
  ["birthDate", "Ngày sinh"],
  ["gender", "Giới tính"],
  ["hometown", "Quê quán"],
  ["address", "Nơi thường trú"],
  ["idIssueDate", "Ngày cấp CCCD"],
  ["licenseNumber", "Số GPLX"],
  ["licenseClass", "Hạng GPLX"],
  ["licenseExpiry", "GPLX có giá trị đến"],
  ["vehiclePlate", "Biển số xe"],
  ["businessLicenseNumber", "Số GPKD"],
  ["businessName", "Tên trên GPKD"],
  ["representativeName", "Người đại diện"],
  ["representativeIdNumber", "Số CCCD người đại diện"],
];

function keyList(raw: unknown): Set<string> {
  return new Set(
    typeof raw === "string"
      ? raw
          .split(",")
          .map((part) => part.trim())
          .filter(Boolean)
      : [],
  );
}

export function readOcrFields(metadata: Record<string, unknown>): OcrField[] {
  const prefilled = keyList(metadata.ocrPrefilled);
  const edited = keyList(metadata.ocrEdited);
  const fields: OcrField[] = [];
  for (const [key, label] of OCR_FIELD_LABELS) {
    const raw = metadata[key];
    const value = typeof raw === "string" ? raw.trim() : "";
    if (!value) {
      continue;
    }
    const source: OcrFieldSource = edited.has(key)
      ? "EDITED"
      : prefilled.has(key)
        ? "OCR"
        : "MANUAL";
    fields.push({ key, label, value, source });
  }
  return fields;
}

/** t61u: why the system did not auto-approve (backend autoApproveBlockers codes). */
export function autoApproveSkipLabels(raw: unknown): string[] {
  const labels: Record<string, string> = {
    DOCUMENT_NOT_STORED: "Giấy tờ chưa lưu",
    ID_NUMBER_FORMAT: "Số CCCD không đủ 12 số",
    VEHICLE_CLASS: "Thiếu hạng xe",
    LICENSE_CLASS_MISMATCH: "Hạng GPLX không khớp xe",
    SHOP_LOCATION: "Thiếu ghim vị trí quán",
  };
  return [...keyList(raw)].map((code) => {
    if (labels[code]) return labels[code];
    if (code.startsWith("FIELD_")) {
      const key = code.slice("FIELD_".length);
      const label = OCR_FIELD_LABELS.find(([k]) => k === key)?.[1] ?? key;
      return `Thiếu ${label}`;
    }
    if (code.startsWith("DEVICE_")) return `Kiểm tra trên máy không đạt (${code.slice(7)})`;
    return code;
  });
}
