import { NextResponse } from "next/server";
import { assertSameOriginMutation, isUuid } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import { readOpsFaqPatchBody } from "@/lib/api/ops-faq-body";

type RouteContext = { params: Promise<{ id: string }> };

export async function PATCH(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }

  const { id } = await context.params;
  if (!isUuid(id)) {
    return NextResponse.json(
      { success: false, message: "FAQ không hợp lệ." },
      { status: 400 },
    );
  }

  const body = await readOpsFaqPatchBody(request);
  if (!body.ok) {
    return NextResponse.json(
      { success: false, message: body.message },
      { status: body.status },
    );
  }

  const result = await fetchOpsUpstream({
    method: "PATCH",
    path: `/v1/ops/faqs/${id}`,
    body: body.payload,
  });
  return jsonFromOpsUpstream(result);
}
