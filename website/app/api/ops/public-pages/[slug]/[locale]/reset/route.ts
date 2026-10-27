import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { checkPublicPageParams } from "@/lib/api/ops-public-page-body";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ slug: string; locale: string }> };

export async function POST(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) return csrf;
  const { slug, locale } = await context.params;
  const p = checkPublicPageParams(slug, locale);
  if (!p.ok) return NextResponse.json({ success: false, message: p.message }, { status: 400 });
  const result = await fetchOpsUpstream({
    method: "POST",
    path: `/v1/ops/public-pages/${p.slug}/${p.locale}/reset`,
  });
  return jsonFromOpsUpstream(result);
}
