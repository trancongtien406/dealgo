import { describe, expect, it } from "vitest";
import { mapNestFaq, faqAudienceLabel } from "@/features/faqs/mappers";
import {
  readOpsFaqCreateBody,
  readOpsFaqPatchBody,
} from "@/lib/api/ops-faq-body";

const base = {
  id: "f",
  openId: null,
  question: "Hỏi?",
  suggestedAnswer: "Đáp",
  status: "PUBLISHED",
  category: "OPS",
  sortOrder: 1,
  updatedAt: "2026-10-19T00:00:00.000Z",
};

function req(body: unknown): Request {
  return new Request("http://localhost/api/ops/faqs", {
    method: "POST",
    body: JSON.stringify(body),
  });
}

describe("FAQ audience", () => {
  it("maps audience and defaults unknown values to INTERNAL", () => {
    expect(mapNestFaq({ ...base, audience: "CUSTOMER" }).audience).toBe(
      "CUSTOMER",
    );
    expect(mapNestFaq({ ...base, audience: "X" }).audience).toBe("INTERNAL");
    expect(mapNestFaq(base).audience).toBe("INTERNAL");
    expect(faqAudienceLabel("DRIVER")).toBe("Tài xế (app)");
  });

  it("validates audience on create and patch", async () => {
    const ok = await readOpsFaqCreateBody(
      req({
        question: "Hủy đơn?",
        suggestedAnswer: "Trước khi quán nhận.",
        category: "OPS",
        audience: "CUSTOMER",
        reason: "seed help",
      }),
    );
    expect(ok.ok && ok.payload.audience).toBe("CUSTOMER");
    const bad = await readOpsFaqPatchBody(
      req({ audience: "EVERYONE", reason: "change" }),
    );
    expect(bad).toMatchObject({ ok: false, status: 400 });
    const patch = await readOpsFaqPatchBody(
      req({ audience: "MERCHANT", reason: "change" }),
    );
    expect(patch.ok && patch.payload.audience).toBe("MERCHANT");
  });
});
