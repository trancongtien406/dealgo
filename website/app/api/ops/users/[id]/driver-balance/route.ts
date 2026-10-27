import { NextResponse } from "next/server";
import { isUuid } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ id: string }> };

/** Fees + signed adjustments vs DRIVER_DEBT_LIMIT_VND, with the recent ledger. */
export async function GET(_request: Request, context: RouteContext) {
  const { id } = await context.params;
  if (!isUuid(id)) {
    return NextResponse.json(
      { success: false, message: "Mã người dùng không hợp lệ." },
      { status: 400 },
    );
  }
  const result = await fetchOpsUpstream({
    path: `/v1/ops/users/${id}/driver-balance`,
  });
  return jsonFromOpsUpstream(result);
}
