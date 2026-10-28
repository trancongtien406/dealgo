import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { readOpsJsonObject } from "@/lib/api/ops-json-body";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

/** Same-origin JSON mutation forwarded to a fixed Nest ops path. */
export async function forwardOpsJsonMutation(
  request: Request,
  method: "POST" | "PUT",
  path: string,
) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const read = await readOpsJsonObject(request);
  if (!read.ok) {
    return NextResponse.json(
      { success: false, message: read.message },
      { status: read.status },
    );
  }
  const result = await fetchOpsUpstream({ method, path, body: read.body });
  return jsonFromOpsUpstream(result);
}
