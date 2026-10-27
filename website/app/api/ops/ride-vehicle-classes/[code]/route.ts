import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ code: string }> };

const PATCH_KEYS = [
  "enabled",
  "name",
  "seats",
  "baseFareVnd",
  "perKmVnd",
  "perMinuteVnd",
  "minFareVnd",
  "maxFareVnd",
  "assumedSpeedKmh",
] as const;

export async function PATCH(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }

  const { code } = await context.params;
  if (!/^[A-Za-z0-9_]{1,32}$/.test(code)) {
    return NextResponse.json(
      { success: false, message: "Mã loại xe không hợp lệ." },
      { status: 400 },
    );
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

  const source = body as Record<string, unknown>;
  const patch: Record<string, unknown> = {};
  for (const key of PATCH_KEYS) {
    if (key in source) {
      patch[key] = source[key];
    }
  }

  const result = await fetchOpsUpstream({
    method: "PATCH",
    path: `/v1/ops/ride-vehicle-classes/${encodeURIComponent(code.toUpperCase())}`,
    body: patch,
  });
  return jsonFromOpsUpstream(result);
}
