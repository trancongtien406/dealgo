/**
 * t88u: mirrors backend LICENSE_CLASSES_FOR_VEHICLE (partner.constants.ts) — Luật TTATGT
 * đường bộ 2024 classes plus older cards still valid (A2, B1, B2, E).
 */
export const LICENSE_CLASSES_FOR_VEHICLE: Record<string, readonly string[]> = {
  MOTORBIKE: ["A1", "A", "A2"],
  CAR_4: ["B", "B1", "B2", "C1", "C", "D1", "D2", "D", "E"],
  CAR_7: ["B", "B1", "B2", "C1", "C", "D1", "D2", "D", "E"],
};

const VEHICLE_CLASS_VI: Record<string, string> = {
  MOTORBIKE: "Xe máy",
  CAR_4: "Ô tô 4 chỗ",
  CAR_7: "Ô tô 7 chỗ",
};

/**
 * Whether ops may approve [vehicleClassCode] for the declared licence. A quick registration
 * (documents waived) never asked for a licence, so nothing is blocked there.
 */
export function licenseAllowsVehicleClass(
  licenseClass: string | null | undefined,
  vehicleClassCode: string,
  documentsWaived: boolean,
): boolean {
  const lic = licenseClass?.trim().toUpperCase() ?? "";
  if (documentsWaived || !lic) return true;
  return (LICENSE_CLASSES_FOR_VEHICLE[vehicleClassCode] ?? []).includes(lic);
}

const MISMATCH = /Licen[cs]e class (\S+) does not cover (\S+)/i;

/** Vietnamese, actionable text for PARTNER_LICENSE_CLASS_MISMATCH; null for other errors. */
export function licenseMismatchMessage(message: string): string | null {
  const m = MISMATCH.exec(message);
  if (!m) return null;
  const lic = m[1]!.toUpperCase();
  const vehicle = VEHICLE_CLASS_VI[m[2]!.toUpperCase()] ?? m[2]!;
  return (
    `Hạng GPLX ${lic} không được lái ${vehicle}, nên không duyệt được. ` +
    "Chọn hạng xe đúng với GPLX, hoặc chọn “Yêu cầu bổ sung” (mục Giấy phép lái xe / Phương tiện) để tài xế khai lại."
  );
}

const CAR_DOCS = /Car KYC documents required/i;

/** t90u: Vietnamese text for PARTNER_CAR_DOCS_REQUIRED (approve blocked); null otherwise. */
export function carDocsRequiredMessage(message: string): string | null {
  if (!CAR_DOCS.test(message)) return null;
  return (
    "Tài xế ô tô chưa có ảnh bảo hiểm xe nên chưa duyệt được. " +
    "Chọn “Yêu cầu bổ sung” (mục Phương tiện) để tài xế tải lên, hoặc tắt cài đặt “Bắt buộc giấy tờ ô tô” trong Cài đặt."
  );
}
