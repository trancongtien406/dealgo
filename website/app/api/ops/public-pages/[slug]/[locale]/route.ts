import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { checkPublicPageDraftBody, checkPublicPageParams } from "@/lib/api/ops-public-page-body";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ slug: string; locale: string }> };

function bad(message: string) {
  return NextResponse.json({ success: false, message }, { status: 400 });
}

export async function GET(_request: Request, context: RouteContext) {
  const { slug, locale } = await context.params;
  const p = checkPublicPageParams(slug, locale);
  if (!p.ok) return bad(p.message);
  const result = await fetchOpsUpstream({ method: "GET", path: `/v1/ops/public-pages/${p.slug}/${p.locale}` });
  return jsonFromOpsUpstream(result);
}

export async function PUT(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) return csrf;
  const { slug, locale } = await context.params;
  const p = checkPublicPageParams(slug, locale);
  if (!p.ok) return bad(p.message);
  let json: unknown;
  try {
    json = await request.json();
  } catch {
    return bad("Yêu cầu không hợp lệ.");
  }
  const body = checkPublicPageDraftBody(json);
  if (!body.ok) return bad(body.message);
  const result = await fetchOpsUpstream({
    method: "PUT",
    path: `/v1/ops/public-pages/${p.slug}/${p.locale}`,
    body: body.value,
  });
  return jsonFromOpsUpstream(result);
}
