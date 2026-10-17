import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const status = url.searchParams.get("status");
  const searchParams: Record<string, string | undefined> = {};
  if (status && status !== "ALL") {
    searchParams.status = status;
  } else if (status === "ALL") {
    searchParams.status = "ALL";
  }

  const result = await fetchOpsUpstream({
    path: "/v1/ops/zones",
    searchParams,
  });
  return jsonFromOpsUpstream(result);
}

export async function POST(request: Request) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }

  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return NextResponse.json(
      { success: false, message: "Dữ liệu JSON không hợp lệ." },
      { status: 400 },
    );
  }

  const result = await fetchOpsUpstream({
    method: "POST",
    path: "/v1/ops/zones",
    body,
  });
  return jsonFromOpsUpstream(result);
}
