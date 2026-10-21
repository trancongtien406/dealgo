import { NextResponse } from "next/server";
import { isUuid } from "@/lib/api/ops-bff-guards";
import { binaryFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstreamBinary } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ id: string; index: string }> };

/** Streams one stored KYC/KYB document for review (ops session only). */
export async function GET(_request: Request, context: RouteContext) {
  const { id, index } = await context.params;
  if (!isUuid(id) || !/^\d{1,2}$/.test(index)) {
    return NextResponse.json(
      { success: false, message: "Mã giấy tờ không hợp lệ." },
      { status: 400 },
    );
  }
  return binaryFromOpsUpstream(
    await fetchOpsUpstreamBinary(`/v1/ops/partner-applications/${id}/documents/${index}`),
  );
}
