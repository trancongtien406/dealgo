import { NextResponse } from "next/server";
import { assertSameOriginMutation, isUuid } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { checkDriverCreditRefund } from "@/lib/api/ops-driver-credit-body";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ id: string }> };

/** Ops records the manual bank transfer that returns unused prepaid credit. */
export async function POST(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const { id } = await context.params;
  if (!isUuid(id)) {
    return NextResponse.json(
      { success: false, message: "Mã lệnh nạp không hợp lệ." },
      { status: 400 },
    );
  }
  let json: unknown;
  try {
    json = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, message: "Yêu cầu không hợp lệ." },
      { status: 400 },
    );
  }
  const body = typeof json === "object" && json !== null ? json : {};
  const checked = checkDriverCreditRefund(body as Record<string, unknown>);
  if (!checked.ok) {
    return NextResponse.json(
      { success: false, message: checked.message },
      { status: 400 },
    );
  }
  const result = await fetchOpsUpstream({
    method: "POST",
    path: `/v1/ops/driver-credit/top-ups/${id}/refund`,
    body: checked.value,
  });
  return jsonFromOpsUpstream(result);
}
