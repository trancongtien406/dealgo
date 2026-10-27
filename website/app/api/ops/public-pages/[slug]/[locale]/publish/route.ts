import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { checkPublicPageParams } from "@/lib/api/ops-public-page-body";
import { checkOpsReason } from "@/lib/api/ops-reason-body";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ slug: string; locale: string }> };

/** Publish the draft as a new version; audited with reason in Nest. */
export async function POST(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) return csrf;
  const { slug, locale } = await context.params;
  const p = checkPublicPageParams(slug, locale);
  if (!p.ok) return NextResponse.json({ success: false, message: p.message }, { status: 400 });
  const json = (await request.json().catch(() => null)) as { reason?: unknown } | null;
  const reason = checkOpsReason({ reason: json?.reason });
  if (!reason.ok) return NextResponse.json({ success: false, message: reason.message }, { status: 400 });
  const result = await fetchOpsUpstream({
    method: "POST",
    path: `/v1/ops/public-pages/${p.slug}/${p.locale}/publish`,
    body: reason.value,
  });
  return jsonFromOpsUpstream(result);
}
