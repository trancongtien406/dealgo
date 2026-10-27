import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { checkChatReviewBody } from "@/lib/api/ops-chat-review-body";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

/** DEC-PROD-056: audited decrypt of a ride/order chat (Nest checks chat.review). */
export async function POST(request: Request) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  let json: unknown;
  try {
    json = await request.json();
  } catch {
    return NextResponse.json({ success: false, message: "Yêu cầu không hợp lệ." }, { status: 400 });
  }
  const body = checkChatReviewBody(json);
  if (!body.ok) {
    return NextResponse.json({ success: false, message: body.message }, { status: 400 });
  }
  const result = await fetchOpsUpstream({
    method: "POST",
    path: "/v1/ops/chat-review",
    body: body.value,
  });
  return jsonFromOpsUpstream(result);
}
