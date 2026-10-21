import { NextResponse } from "next/server";
import { assertSameOriginMutation, isUuid } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import {
  checkOpsSuperAdminChange,
  opsAccountActionErrorMessage,
} from "@/lib/api/ops-reason-body";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ id: string }> };

/** Super-admin grants/revokes the super-admin flag (audited, never the last one). */
export async function POST(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const { id } = await context.params;
  if (!isUuid(id)) {
    return NextResponse.json(
      { success: false, message: "Mã nhân sự không hợp lệ." },
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
  const checked = checkOpsSuperAdminChange(body as Record<string, unknown>);
  if (!checked.ok) {
    return NextResponse.json({ success: false, message: checked.message }, { status: 400 });
  }
  const result = await fetchOpsUpstream({
    method: "POST",
    path: `/v1/ops/staff/${id}/super-admin`,
    body: checked.value,
  });
  if (!result.ok) {
    const message = opsAccountActionErrorMessage(result.errorCode);
    return jsonFromOpsUpstream(message ? { ...result, message } : result);
  }
  return jsonFromOpsUpstream(result);
}
