import { describe, expect, it } from "vitest";
import { buildKycQueueSearch } from "@/features/kyc/api";
import { mapNestPartnerApplicationToKycCase } from "@/features/kyc/mappers";

describe("driver KYC queue", () => {
  it("filters the Nest list by partner type", () => {
    const search = buildKycQueueSearch({ status: "ALL", role: "DRIVER", page: 1, limit: 20 });
    expect(search.get("role")).toBe("DRIVER");
    expect(search.get("status")).toBe("SUBMITTED");
    expect(buildKycQueueSearch({ status: "ALL", page: 1, limit: 20 } as never).has("role")).toBe(false);
  });

  it("case shows the applicant phone, then the masked one", () => {
    const base = {
      id: "a1",
      role: "DRIVER",
      status: "SUBMITTED",
      metadata: { fullName: "Nguyen Van Test", phoneMasked: "+849****101" },
      documents: [],
      reason: null,
      issues: [],
      reviewedBy: null,
      reviewedAt: null,
      submittedAt: "2026-10-25T06:00:00.000Z",
      createdAt: "2026-10-25T06:00:00.000Z",
      updatedAt: "2026-10-25T06:00:00.000Z",
    } as never as Parameters<typeof mapNestPartnerApplicationToKycCase>[0];
    expect(mapNestPartnerApplicationToKycCase({ ...base, applicantPhone: "+84909990101" }).phoneMasked).toBe("+84909990101");
    expect(mapNestPartnerApplicationToKycCase(base).phoneMasked).toBe("+849****101");
  });
});
