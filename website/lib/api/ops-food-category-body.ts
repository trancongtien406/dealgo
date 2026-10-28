/** BFF guards for `/api/ops/food-categories/*` before forwarding to Nest (DEC-PROD-067). */
import type { BodyCheck } from "@/lib/api/ops-home-banner-body";

export const FOOD_CATEGORY_CODE_RE = /^[a-z0-9]+(?:_[a-z0-9]+)*$/;

const BODY_KEYS = ["nameVi", "nameEn", "icon", "tone", "active", "imageUrl"] as const;

function isRecord(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === "object" && !Array.isArray(value);
}

export function isFoodCategoryCode(code: string): boolean {
  return code.length <= 64 && FOOD_CATEGORY_CODE_RE.test(code);
}

/** Keeps only the fields Nest accepts; Nest does the full validation. */
export function pickFoodCategoryBody(
  body: unknown,
): BodyCheck<Record<string, unknown>> {
  if (!isRecord(body)) {
    return { ok: false, message: "Dữ liệu không hợp lệ." };
  }
  const value: Record<string, unknown> = {};
  for (const key of BODY_KEYS) {
    if (key in body) value[key] = body[key];
  }
  if (Object.keys(value).length === 0) {
    return { ok: false, message: "Không có trường nào để lưu." };
  }
  return { ok: true, value };
}

export function checkFoodCategoryReorderBody(
  body: unknown,
): BodyCheck<{ codes: string[] }> {
  const codes = isRecord(body) ? body.codes : undefined;
  if (
    !Array.isArray(codes) ||
    codes.length === 0 ||
    codes.length > 200 ||
    !codes.every((c) => typeof c === "string" && isFoodCategoryCode(c)) ||
    new Set(codes).size !== codes.length
  ) {
    return { ok: false, message: "Danh sách danh mục không hợp lệ." };
  }
  return { ok: true, value: { codes: codes as string[] } };
}

export function checkFoodCategoryImageBody(
  body: unknown,
): BodyCheck<{ dataUrl: string }> {
  const dataUrl = isRecord(body) ? body.dataUrl : undefined;
  if (
    typeof dataUrl !== "string" ||
    !/^data:image\/(jpeg|png|webp);base64,/.test(dataUrl)
  ) {
    return { ok: false, message: "Chọn ảnh JPEG, PNG hoặc WebP." };
  }
  if (dataUrl.length > 1_390_000) {
    return { ok: false, message: "Ảnh tối đa 1 MB." };
  }
  return { ok: true, value: { dataUrl } };
}
