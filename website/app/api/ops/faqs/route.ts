import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import { readOpsFaqCreateBody } from "@/lib/api/ops-faq-body";

export async function GET(request: Request) {
  const status = new URL(request.url).searchParams.get("status") ?? undefined;
  const result = await fetchOpsUpstream({
    path: "/v1/ops/faqs",
    searchParams: status ? { status } : undefined,
  });
  return jsonFromOpsUpstream(result);
}

export async function POST(request: Request) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }

  const body = await readOpsFaqCreateBody(request);
  if (!body.ok) {
    return NextResponse.json(
      { success: false, message: body.message },
      { status: body.status },
    );
  }

  const result = await fetchOpsUpstream({
    method: "POST",
    path: "/v1/ops/faqs",
    body: body.payload,
  });
  return jsonFromOpsUpstream(result);
}
