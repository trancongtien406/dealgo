/**
 * t52u: read the advisory checks attached to a KYC/KYB application.
 * - capture*: reported by the partner app's on-device checks (blur/glare/face/liveness) — the
 *   device can lie, so the UI labels them "thiết bị báo".
 * t56u: there is no AI verdict (no OCR / face match / server AI). Staff review is fully manual.
 */
export type KycCheckTone = "ok" | "warn" | "muted";

export type KycCheckRow = { label: string; value: string; tone: KycCheckTone };

export type KycReviewChecks = {
  device: KycCheckRow[];
};

const DEVICE_FLAGS: Array<[string, string]> = [
  ["captureIdFrontQualityOk", "CCCD mặt trước rõ nét"],
  ["captureIdBackQualityOk", "CCCD mặt sau rõ nét"],
  ["captureRepIdFrontQualityOk", "CCCD đại diện mặt trước rõ nét"],
  ["captureRepIdBackQualityOk", "CCCD đại diện mặt sau rõ nét"],
  ["captureFaceDetected", "Phát hiện 1 khuôn mặt"],
  ["captureLivenessPassed", "Kiểm tra người thật (quay trái/phải, chớp mắt)"],
  ["captureLivenessVideo", "Có video quay khuôn mặt"],
];

export function readKycReviewChecks(
  metadata: Record<string, unknown>,
): KycReviewChecks {
  const device: KycCheckRow[] = [];
  for (const [key, label] of DEVICE_FLAGS) {
    const value = metadata[key];
    if (typeof value === "boolean") {
      device.push({
        label,
        value: value ? "Đạt" : "Không đạt",
        tone: value ? "ok" : "warn",
      });
    }
  }
  return { device };
}

/** Front / back / face triple for the side-by-side compare panel (driver or merchant rep). */
export function pickIdentityTriple<T extends { kind: string | null }>(
  documents: T[],
): { front: T | null; back: T | null; face: T | null; clip: T | null } {
  const find = (...kinds: string[]) =>
    documents.find((d) => d.kind && kinds.includes(d.kind)) ?? null;
  return {
    front: find("ID_FRONT", "REP_ID_FRONT"),
    back: find("ID_BACK", "REP_ID_BACK"),
    face: find("SELFIE"),
    clip: find("SELFIE_VIDEO"),
  };
}
