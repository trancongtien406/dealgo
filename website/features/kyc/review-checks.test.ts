import { describe, expect, it } from "vitest";
import {
  pickIdentityTriple,
  readKycReviewChecks,
} from "@/features/kyc/review-checks";
import {
  kycFilterToNestPartnerStatus,
  nestPartnerStatusToFeature,
} from "@/features/kyc/mappers";

describe("KYC review checks (t52u)", () => {
  it("reads device-reported capture flags, ignoring non-booleans", () => {
    const checks = readKycReviewChecks({
      captureIdFrontQualityOk: true,
      captureLivenessPassed: false,
      captureFaceDetected: "yes",
    });
    expect(checks.device).toEqual([
      { label: "CCCD mặt trước rõ nét", value: "Đạt", tone: "ok" },
      {
        label: "Kiểm tra người thật (quay trái/phải, chớp mắt)",
        value: "Không đạt",
        tone: "warn",
      },
    ]);
  });

  it("picks front/back/face for drivers and merchant reps", () => {
    const docs = [
      { kind: "SELFIE" },
      { kind: "ID_BACK" },
      { kind: "ID_FRONT" },
      { kind: "SELFIE_VIDEO" },
      { kind: null },
    ];
    expect(pickIdentityTriple(docs)).toEqual({
      front: { kind: "ID_FRONT" },
      back: { kind: "ID_BACK" },
      face: { kind: "SELFIE" },
      clip: { kind: "SELFIE_VIDEO" },
    });
    expect(pickIdentityTriple([{ kind: "REP_ID_FRONT" }])).toEqual({
      front: { kind: "REP_ID_FRONT" },
      back: null,
      face: null,
      clip: null,
    });
  });

  it("maps the IN_REVIEW status both ways", () => {
    expect(nestPartnerStatusToFeature("IN_REVIEW")).toBe("IN_REVIEW");
    expect(kycFilterToNestPartnerStatus("IN_REVIEW")).toBe("IN_REVIEW");
  });
});
