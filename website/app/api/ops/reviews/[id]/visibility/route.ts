import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

export async function PATCH(
  request: Request,
  props: { params: Promise<{ id: string }> },
) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const { id } = await props.params;
  if (!id?.trim()) {
    return NextResponse.json(
      { success: false, message: "Mã đánh giá không hợp lệ." },
      { status: 400 },
    );
  }
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, message: "Dữ liệu JSON không hợp lệ." },
      { status: 400 },
    );
  }
  const result = await fetchOpsUpstream({
    method: "PATCH",
    path: `/v1/ops/reviews/${encodeURIComponent(id)}/visibility`,
    body,
  });
  return jsonFromOpsUpstream(result);
}
