import { NextResponse } from "next/server";
import { getLegalPage, getSupportPage } from "@/features/content-cms/fetch-public-page";
import { isPublicPageSlug, localeFromLang } from "@/features/content-cms/types";

/** Public read of a published CMS page (DEC-PROD-055): ?key=terms|privacy|support&lang=vi|en. */
export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const key = searchParams.get("key")?.toLowerCase() ?? "";
  if (!isPublicPageSlug(key)) {
    return NextResponse.json(
      { success: false, message: "Tài liệu công khai không tồn tại." },
      { status: 404 },
    );
  }
  const locale = localeFromLang(searchParams.get("lang") ?? searchParams.get("locale") ?? undefined);
  const data = key === "support" ? await getSupportPage(locale) : await getLegalPage(key, locale);
  return NextResponse.json({ success: true, data });
}
