import { NextResponse } from "next/server";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { checkPublicPageParams } from "@/lib/api/ops-public-page-body";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ slug: string; locale: string }> };

export async function GET(_request: Request, context: RouteContext) {
  const { slug, locale } = await context.params;
  const p = checkPublicPageParams(slug, locale);
  if (!p.ok) return NextResponse.json({ success: false, message: p.message }, { status: 400 });
  const result = await fetchOpsUpstream({
    method: "GET",
    path: `/v1/ops/public-pages/${p.slug}/${p.locale}/revisions`,
  });
  return jsonFromOpsUpstream(result);
}
