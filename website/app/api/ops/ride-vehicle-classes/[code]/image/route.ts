import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ code: string }> };

function rejectCode(code: string) {
  if (!/^[A-Za-z0-9_]{1,32}$/.test(code)) {
    return NextResponse.json(
      { success: false, message: "Mã loại xe không hợp lệ." },
      { status: 400 },
    );
  }
  return null;
}

export async function POST(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const { code } = await context.params;
  const invalid = rejectCode(code);
  if (invalid) {
    return invalid;
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, message: "Dữ liệu không hợp lệ." },
      { status: 400 },
    );
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return NextResponse.json(
      { success: false, message: "Dữ liệu không hợp lệ." },
      { status: 400 },
    );
  }
  const dataUrl = (body as { dataUrl?: unknown }).dataUrl;
  if (typeof dataUrl !== "string" || !dataUrl.startsWith("data:image/")) {
    return NextResponse.json(
      { success: false, message: "Chọn ảnh JPEG, PNG hoặc WebP." },
      { status: 400 },
    );
  }

  const result = await fetchOpsUpstream({
    method: "POST",
    path: `/v1/ops/ride-vehicle-classes/${encodeURIComponent(code.toUpperCase())}/image`,
    body: { dataUrl },
  });
  return jsonFromOpsUpstream(result);
}

export async function DELETE(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const { code } = await context.params;
  const invalid = rejectCode(code);
  if (invalid) {
    return invalid;
  }
  const result = await fetchOpsUpstream({
    method: "DELETE",
    path: `/v1/ops/ride-vehicle-classes/${encodeURIComponent(code.toUpperCase())}/image`,
  });
  return jsonFromOpsUpstream(result);
}
