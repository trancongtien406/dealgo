import { describe, expect, it } from "vitest";
import { mapNestPartnerApplicationToKycCase } from "@/features/kyc/mappers";
import type { NestPartnerApplicationView } from "@/features/kyc/nest-types";
import {
  formatBytes,
  maskAccountNumber,
  mapPartnerDocuments,
  validateIssues,
} from "@/features/kyc/partner-review";
import { mapNestToStoreApproval } from "@/features/store-approvals/api";

const ID = "6f1c2b8e-3a1d-4c2e-9f7a-1b2c3d4e5f60";

function app(
  over: Partial<NestPartnerApplicationView> = {},
): NestPartnerApplicationView {
  return {
    id: ID,
    role: "DRIVER",
    status: "SUBMITTED",
    metadata: {},
    documents: [],
    reason: null,
    issues: [],
    reviewedBy: null,
    reviewedAt: null,
    submittedAt: "2026-10-19T03:00:00.000Z",
    createdAt: "2026-10-19T03:00:00.000Z",
    updatedAt: "2026-10-19T03:00:00.000Z",
    ...over,
  };
}

describe("partner review helpers", () => {
  it("maps documents to BFF URLs and hides seed refs without bytes", () => {
    const docs = mapPartnerDocuments(
      app({
        documents: [
          {
            index: 0,
            kind: "ID_FRONT",
            label: "x",
            contentType: "image/jpeg",
            sizeBytes: 2048,
            uploadedAt: "2026-10-19T03:00:00.000Z",
            hasFile: true,
          },
          {
            index: 1,
            kind: "LICENSE",
            label: "y",
            contentType: "application/pdf",
            sizeBytes: 0,
            uploadedAt: "2026-10-19T03:00:00.000Z",
            hasFile: false,
          },
        ],
      }),
    );
    expect(docs[0]).toMatchObject({
      label: "CCCD — mặt trước",
      isImage: true,
      url: `/api/ops/partner-applications/${ID}/documents/0`,
      sizeLabel: "2 KB",
    });
    expect(docs[1]).toMatchObject({
      label: "Giấy phép lái xe",
      url: null,
      hasFile: false,
    });
  });

  it("formats sizes, masks account numbers and validates issues", () => {
    expect(formatBytes(0)).toBe("—");
    expect(formatBytes(3 * 1024 * 1024)).toBe("3,0 MB");
    expect(maskAccountNumber("0123 4567 89")).toBe("•••• 6789");
    expect(validateIssues([])).not.toBeNull();
    expect(validateIssues([{ section: "SELFIE", note: " " }])).not.toBeNull();
    expect(validateIssues([{ section: "SELFIE", note: "Ảnh mờ" }])).toBeNull();
  });

  it("reads the field names the mobile app sends", () => {
    const kyc = mapNestPartnerApplicationToKycCase(
      app({
        status: "REJECTED",
        reason: "Bổ sung",
        issues: [{ section: "SELFIE", note: "Ảnh mờ" }],
        metadata: {
          fullName: "Trần Công Tiến",
          vehiclePlate: "59X1-123.45",
          vehicleBrand: "Honda",
          vehicleModel: "Wave",
          bankAccountNumber: "0123456789",
        },
      }),
    );
    expect(kyc.plate).toBe("59X1-123.45");
    expect(kyc.vehicle).toBe("Honda Wave");
    expect(kyc.issues).toEqual([{ section: "SELFIE", note: "Ảnh mờ" }]);
    expect(kyc.details).toContainEqual(["Số tài khoản", "•••• 6789"]);
    expect(kyc.details.some(([, v]) => v.includes("0123456789"))).toBe(false);

    const store = mapNestToStoreApproval(
      app({
        role: "MERCHANT",
        metadata: {
          shopName: "Cơm Tấm Sài Gòn",
          shopAddress: "12 Lê Lợi",
          representativeName: "Lê Bình",
          businessType: "CAFE_TEA",
          registrationSubject: "HOUSEHOLD",
        },
      }),
    );
    expect(store).toMatchObject({
      name: "Cơm Tấm Sài Gòn",
      owner: "Lê Bình",
      address: "12 Lê Lợi",
      category: "Quán cà phê / Trà sữa",
      registrationType: "Hộ kinh doanh",
    });
  });
});
