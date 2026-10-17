import { NextResponse } from "next/server";
import {
  isAuthMethodCode,
  readAuthMethodPatchBody,
} from "@/lib/api/ops-auth-method-body";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ method: string }> };

export async function PATCH(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }

  const { method } = await context.params;
  if (!isAuthMethodCode(method)) {
    return NextResponse.json(
      { success: false, message: "Phương thức không hợp lệ." },
      { status: 400 },
    );
  }

  const body = await readAuthMethodPatchBody(request);
  if (!body.ok) {
    return NextResponse.json(
      { success: false, message: body.message },
      { status: body.status },
    );
  }

  const result = await fetchOpsUpstream({
    method: "PATCH",
    path: `/v1/ops/auth-methods/${method}`,
    body: { enabled: body.enabled, reason: body.reason },
  });
  return jsonFromOpsUpstream(result);
}
