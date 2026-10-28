import { describe, expect, it } from "vitest";
import {
  checkFoodCategoryImageBody,
  checkFoodCategoryReorderBody,
  isFoodCategoryCode,
  pickFoodCategoryBody,
} from "@/lib/api/ops-food-category-body";

describe("ops food category BFF guards", () => {
  it("accepts snake_case codes only", () => {
    expect(isFoodCategoryCode("bun_bo_hue")).toBe(true);
    expect(isFoodCategoryCode("Bún")).toBe(false);
    expect(isFoodCategoryCode("../x")).toBe(false);
  });

  it("keeps only known fields", () => {
    expect(pickFoodCategoryBody({ nameVi: "Phở", code: "x", sortOrder: 3 })).toEqual({
      ok: true,
      value: { nameVi: "Phở" },
    });
    expect(pickFoodCategoryBody({ code: "x" }).ok).toBe(false);
    expect(pickFoodCategoryBody([]).ok).toBe(false);
  });

  it("validates reorder lists", () => {
    expect(checkFoodCategoryReorderBody({ codes: ["pho", "rice"] })).toEqual({
      ok: true,
      value: { codes: ["pho", "rice"] },
    });
    expect(checkFoodCategoryReorderBody({ codes: ["pho", "pho"] }).ok).toBe(false);
    expect(checkFoodCategoryReorderBody({ codes: [] }).ok).toBe(false);
    expect(checkFoodCategoryReorderBody({ codes: ["Phở"] }).ok).toBe(false);
  });

  it("only forwards small JPEG/PNG/WebP data URLs", () => {
    expect(checkFoodCategoryImageBody({ dataUrl: "data:image/png;base64,AAAA" }).ok).toBe(true);
    expect(checkFoodCategoryImageBody({ dataUrl: "data:image/gif;base64,AAAA" }).ok).toBe(false);
    expect(
      checkFoodCategoryImageBody({ dataUrl: `data:image/png;base64,${"A".repeat(1_400_000)}` }).ok,
    ).toBe(false);
  });
});
