/** BFF guards for `/api/ops/home-banners/*` before forwarding to Nest. */

export const HOME_BANNER_ID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const BODY_KEYS = [
  "ctaUrl",
  "audiences",
  "service",
  "regionCode",
  "startsAt",
  "endsAt",
  "sortOrder",
  "active",
] as const;

export type BodyCheck<T> =
  { ok: true; value: T } | { ok: false; message: string };

function isRecord(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === "object" && !Array.isArray(value);
}

/** Keeps only the banner fields Nest accepts; Nest does the full validation. */
export function pickHomeBannerBody(
  body: unknown,
): BodyCheck<Record<string, unknown>> {
  if (!isRecord(body)) {
    return { ok: false, message: "Dữ liệu không hợp lệ." };
  }
  const value: Record<string, unknown> = {};
  for (const key of BODY_KEYS) {
    if (key in body) {
      value[key] = body[key];
    }
  }
  if (Object.keys(value).length === 0) {
    return { ok: false, message: "Không có trường nào để lưu." };
  }
  return { ok: true, value };
}

export function checkHomeBannerReorderBody(
  body: unknown,
): BodyCheck<{ ids: string[] }> {
  if (!isRecord(body) || !Array.isArray(body.ids) || body.ids.length === 0) {
    return { ok: false, message: "Danh sách banner không hợp lệ." };
  }
  const ids = body.ids;
  if (
    ids.length > 200 ||
    !ids.every((id) => typeof id === "string" && HOME_BANNER_ID_RE.test(id)) ||
    new Set(ids).size !== ids.length
  ) {
    return { ok: false, message: "Danh sách banner không hợp lệ." };
  }
  return { ok: true, value: { ids: ids as string[] } };
}

export function checkHomeBannerImageBody(
  body: unknown,
): BodyCheck<{ dataUrl: string }> {
  const dataUrl = isRecord(body) ? body.dataUrl : undefined;
  if (
    typeof dataUrl !== "string" ||
    !/^data:image\/(jpeg|png|webp);base64,/.test(dataUrl)
  ) {
    return { ok: false, message: "Chọn ảnh JPEG, PNG hoặc WebP." };
  }
  if (dataUrl.length > 2_700_000) {
    return { ok: false, message: "Ảnh tối đa 2 MB." };
  }
  return { ok: true, value: { dataUrl } };
}
