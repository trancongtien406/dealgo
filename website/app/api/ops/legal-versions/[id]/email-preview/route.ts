import { NextResponse } from "next/server";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ id: string }> };
const UUID = /^[0-9a-f-]{36}$/i;

export async function GET(_request: Request, context: RouteContext) {
  const { id } = await context.params;
  if (!UUID.test(id)) return NextResponse.json({ success: false, message: "Không tìm thấy." }, { status: 404 });
  return jsonFromOpsUpstream(await fetchOpsUpstream({ path: `/v1/ops/legal-versions/${id}/email-preview` }));
}
