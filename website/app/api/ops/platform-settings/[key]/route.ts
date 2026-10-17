import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import { readPlatformSettingPatchBody } from "@/lib/api/ops-platform-setting-body";

type RouteContext = { params: Promise<{ key: string }> };

export async function PATCH(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }

  const { key } = await context.params;
  if (!key || key.length > 64) {
    return NextResponse.json(
      { success: false, message: "Khóa cấu hình không hợp lệ." },
      { status: 400 },
    );
  }

  const body = await readPlatformSettingPatchBody(request);
  if (!body.ok) {
    return NextResponse.json(
      { success: false, message: body.message },
      { status: body.status },
    );
  }

  const result = await fetchOpsUpstream({
    method: "PATCH",
    path: `/v1/ops/platform-settings/${encodeURIComponent(key)}`,
    body: { value: body.value, reason: body.reason },
  });
  return jsonFromOpsUpstream(result);
}
