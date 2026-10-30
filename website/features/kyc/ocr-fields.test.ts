import { describe, expect, it } from "vitest";
import { autoApproveSkipLabels, readOcrFields } from "@/features/kyc/ocr-fields";
import { PARTNER_DOCUMENT_LABELS } from "@/features/kyc/partner-review";

describe("OCR fields (t61u)", () => {
  it("marks scanned, edited and typed values", () => {
    const fields = readOcrFields({
      idNumber: "079090001234",
      fullName: "NGUYỄN VĂN A",
      licenseClass: "A1",
      vehiclePlate: " ",
      ocrPrefilled: "idNumber,fullName",
      ocrEdited: "fullName",
    });
    expect(fields.map((f) => [f.key, f.source])).toEqual([
      ["idNumber", "OCR"],
      ["fullName", "EDITED"],
      ["licenseClass", "MANUAL"],
    ]);
  });

  it("explains auto-approve skips in Vietnamese", () => {
    expect(autoApproveSkipLabels("FIELD_licenseNumber,LICENSE_CLASS_MISMATCH,DEVICE_captureFaceLive")).toEqual([
      "Thiếu Số GPLX",
      "Hạng GPLX không khớp xe",
      "Kiểm tra trên máy không đạt (captureFaceLive)",
    ]);
    expect(autoApproveSkipLabels(undefined)).toEqual([]);
  });

  it("labels the household food-safety commitment", () => {
    expect(PARTNER_DOCUMENT_LABELS.FOOD_SAFETY_COMMITMENT).toContain("cam kết");
  });
});
