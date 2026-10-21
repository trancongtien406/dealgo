import { NextResponse } from "next/server";
import { assertSameOriginMutation, isUuid } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { checkOpsReason, opsAccountActionErrorMessage } from "@/lib/api/ops-reason-body";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ id: string }> };

/** Restore an account during its deletion grace period (S027, audited). */
export async function POST(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const { id } = await context.params;
  if (!isUuid(id)) {
    return NextResponse.json(
      { success: false, message: "Mã người dùng không hợp lệ." },
      { status: 400 },
    );
  }
  let json: unknown;
  try {
    json = await request.json();
  } catch {
    return NextResponse.json({ success: false, message: "Yêu cầu không hợp lệ." }, { status: 400 });
  }
  const body = typeof json === "object" && json !== null ? json : {};
  const checked = checkOpsReason(body as Record<string, unknown>);
  if (!checked.ok) {
    return NextResponse.json({ success: false, message: checked.message }, { status: 400 });
  }
  const result = await fetchOpsUpstream({
    method: "POST",
    path: `/v1/ops/users/${id}/account-deletion/cancel`,
    body: checked.value,
  });
  if (!result.ok) {
    const message = opsAccountActionErrorMessage(result.errorCode);
    return jsonFromOpsUpstream(message ? { ...result, message } : result);
  }
  return jsonFromOpsUpstream(result);
}
