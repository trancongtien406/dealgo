import { isPublicPageLocale, isPublicPageSlug } from "@/features/content-cms/types";

export type PublicPageParamsCheck =
  | { ok: true; slug: string; locale: string }
  | { ok: false; message: string };

export function checkPublicPageParams(slug: string, locale: string): PublicPageParamsCheck {
  if (!isPublicPageSlug(slug) || !isPublicPageLocale(locale)) {
    return { ok: false, message: "Trang không hợp lệ." };
  }
  return { ok: true, slug, locale };
}

export type PublicPageDraftBody = {
  title: string;
  summary: string | null;
  effectiveAt: string | null;
  content: Record<string, unknown>;
};

const MAX_BODY = 100_000;

/** Shape check only; Nest validates the content schema per slug (DEC-PROD-055). */
export function checkPublicPageDraftBody(
  input: unknown,
): { ok: true; value: PublicPageDraftBody } | { ok: false; message: string } {
  if (typeof input !== "object" || input === null) {
    return { ok: false, message: "Yêu cầu không hợp lệ." };
  }
  const raw = input as Record<string, unknown>;
  const title = typeof raw.title === "string" ? raw.title.trim() : "";
  if (title.length < 1 || title.length > 200) {
    return { ok: false, message: "Tiêu đề cần 1–200 ký tự." };
  }
  const summary =
    typeof raw.summary === "string" && raw.summary.trim() ? raw.summary.trim() : null;
  if (summary && summary.length > 500) {
    return { ok: false, message: "Tóm tắt tối đa 500 ký tự." };
  }
  let effectiveAt: string | null = null;
  if (typeof raw.effectiveAt === "string" && raw.effectiveAt) {
    const d = new Date(raw.effectiveAt);
    if (Number.isNaN(d.getTime())) {
      return { ok: false, message: "Ngày hiệu lực không hợp lệ." };
    }
    effectiveAt = d.toISOString();
  }
  if (typeof raw.content !== "object" || raw.content === null || Array.isArray(raw.content)) {
    return { ok: false, message: "Nội dung không hợp lệ." };
  }
  if (JSON.stringify(raw.content).length > MAX_BODY) {
    return { ok: false, message: "Nội dung quá dài." };
  }
  return {
    ok: true,
    value: { title, summary, effectiveAt, content: raw.content as Record<string, unknown> },
  };
}
