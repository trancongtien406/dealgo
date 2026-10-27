import { NextResponse } from "next/server";
import { isUuid } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import { checkStatementRange } from "@/lib/merchant-statement";

type RouteContext = { params: Promise<{ id: string }> };

/** (OPEN-018) Store commission statement by Vietnam day. */
export async function GET(request: Request, context: RouteContext) {
  const { id } = await context.params;
  if (!isUuid(id)) {
    return NextResponse.json(
      { success: false, message: "Mã cửa hàng không hợp lệ." },
      { status: 400 },
    );
  }
  const { searchParams } = new URL(request.url);
  const from = searchParams.get("from");
  const to = searchParams.get("to");
  let range: { from: string; to: string } | null = null;
  if (from || to) {
    const checked = checkStatementRange({ from, to });
    if (!checked.ok) {
      return NextResponse.json(
        { success: false, message: checked.message },
        { status: 400 },
      );
    }
    range = checked.value;
  }
  const result = await fetchOpsUpstream({
    path: `/v1/ops/food-stores/${id}/statement`,
    searchParams: range ?? {},
  });
  return jsonFromOpsUpstream(result);
}
