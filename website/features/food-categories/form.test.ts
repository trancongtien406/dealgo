import { describe, expect, it } from "vitest";
import {
  checkFoodCategoryDraft,
  diffFoodCategoryPayload,
  draftFromFoodCategory,
  emptyFoodCategoryDraft,
  foodCategoryDefaultPhoto,
  foodCategoryImageSrc,
  foodCategoryPhotoSrc,
  moveFoodCategoryCode,
  previewFoodCategoryCode,
  slugifyFoodCategory,
  suggestFoodCategoryLook,
} from "./form";
import type { FoodCategoryRow } from "./types";

const row: FoodCategoryRow = {
  code: "noodles",
  nameVi: "Bún & phở",
  nameEn: "Noodles",
  icon: "soup",
  tone: "orange",
  imageUrl: null,
  sortOrder: 20,
  active: true,
  storeCount: 3,
  createdAt: "2026-10-27T00:00:00.000Z",
  updatedAt: "2026-10-27T00:00:00.000Z",
};

describe("food category form", () => {
  it("slugifies Vietnamese names into codes like the backend", () => {
    expect(slugifyFoodCategory("Bún bò Huế")).toBe("bun_bo_hue");
    expect(slugifyFoodCategory("  Đồ uống!! ")).toBe("do_uong");
  });

  it("previews a unique auto code", () => {
    expect(previewFoodCategoryCode("Cơm tấm", ["rice"])).toBe("com_tam");
    expect(previewFoodCategoryCode("Cơm tấm", ["com_tam"])).toBe("com_tam_2");
  });

  it("suggests an icon and tone from the name", () => {
    expect(suggestFoodCategoryLook("Bún bò")).toEqual({ icon: "soup", tone: "orange" });
    expect(suggestFoodCategoryLook("Cà phê muối")?.icon).toBe("coffee");
    expect(suggestFoodCategoryLook("Trái cây")?.icon).toBe("apple");
    expect(suggestFoodCategoryLook("Xyz")).toBeNull();
  });

  it("trims names and reuses the Vietnamese name for a blank English one", () => {
    const check = checkFoodCategoryDraft({
      ...emptyFoodCategoryDraft(),
      nameVi: "  Bánh   mì ",
    });
    expect(check).toEqual({
      ok: true,
      payload: {
        nameVi: "Bánh mì",
        nameEn: "Bánh mì",
        icon: "utensils",
        tone: "orange",
        active: true,
      },
    });
    expect(
      checkFoodCategoryDraft({ ...emptyFoodCategoryDraft(), nameVi: "A" }).ok,
    ).toBe(false);
  });

  it("sends only changed fields", () => {
    const draft = { ...draftFromFoodCategory(row), tone: "red" as const };
    const check = checkFoodCategoryDraft(draft);
    if (!check.ok) throw new Error(check.message);
    expect(diffFoodCategoryPayload(row, check.payload)).toEqual({ tone: "red" });
  });

  it("moves a dragged code into the target slot", () => {
    const codes = ["a", "b", "c", "d"];
    expect(moveFoodCategoryCode(codes, "a", "c")).toEqual(["b", "c", "a", "d"]);
    expect(moveFoodCategoryCode(codes, "d", "a")).toEqual(["d", "a", "b", "c"]);
    expect(moveFoodCategoryCode(codes, "a", "a")).toBeNull();
    expect(moveFoodCategoryCode(codes, "x", "a")).toBeNull();
  });

  it("maps backend image paths to the BFF proxy only", () => {
    expect(
      foodCategoryImageSrc("/v1/public/food-categories/images/pho/abc.webp"),
    ).toBe("/api/public/food-categories/images/pho/abc.webp");
    expect(foodCategoryImageSrc("https://evil.example/x.png")).toBeNull();
    expect(foodCategoryImageSrc(null)).toBeNull();
  });
});

describe("foodCategoryDefaultPhoto", () => {
  it("uses the seeded code photo, else the icon's photo", () => {
    expect(foodCategoryDefaultPhoto("tea", "soup")).toBe("tea");
    expect(foodCategoryDefaultPhoto("vegan-bowls", "salad")).toBe("snack");
    expect(foodCategoryDefaultPhoto(null, "coffee")).toBe("cafe");
    expect(foodCategoryPhotoSrc("pho")).toBe("/assets/food-categories/pho.jpg");
  });
});
