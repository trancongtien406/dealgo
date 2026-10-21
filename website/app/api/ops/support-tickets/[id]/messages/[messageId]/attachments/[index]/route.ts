import { NextResponse } from "next/server";
import { isUuid } from "@/lib/api/ops-bff-guards";
import { binaryFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstreamBinary } from "@/lib/api/ops-upstream";

type RouteContext = {
  params: Promise<{ id: string; messageId: string; index: string }>;
};

/** Streams one ticket attachment (ops session only). */
export async function GET(_request: Request, context: RouteContext) {
  const { id, messageId, index } = await context.params;
  if (!isUuid(id) || !isUuid(messageId) || !/^[0-2]$/.test(index)) {
    return NextResponse.json(
      { success: false, message: "Tệp đính kèm không hợp lệ." },
      { status: 400 },
    );
  }
  return binaryFromOpsUpstream(
    await fetchOpsUpstreamBinary(
      `/v1/ops/support-tickets/${id}/messages/${messageId}/attachments/${index}`,
    ),
  );
}
