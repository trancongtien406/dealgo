import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = {
  params: Promise<{ regionCode: string; vehicleClassCode: string }>;
};

const CODE = /^[A-Za-z0-9_]{1,32}$/;

function bad(message: string) {
  return NextResponse.json({ success: false, message }, { status: 400 });
}

async function target(context: RouteContext) {
  const { regionCode, vehicleClassCode } = await context.params;
  if (!CODE.test(regionCode) || !CODE.test(vehicleClassCode)) {
    return null;
  }
  return `/v1/ops/ride-zone-tariffs/${encodeURIComponent(regionCode.toUpperCase())}/${encodeURIComponent(vehicleClassCode.toUpperCase())}`;
}

export async function PUT(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const path = await target(context);
  if (!path) {
    return bad("Mã khu vực hoặc loại xe không hợp lệ.");
  }
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return bad("Dữ liệu không hợp lệ.");
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return bad("Dữ liệu không hợp lệ.");
  }
  const source = body as Record<string, unknown>;
  const result = await fetchOpsUpstream({
    method: "PUT",
    path,
    body: {
      perKmVnd: source.perKmVnd,
      minFareVnd: source.minFareVnd,
      ...(typeof source.reason === "string" ? { reason: source.reason } : {}),
    },
  });
  return jsonFromOpsUpstream(result);
}

export async function DELETE(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const path = await target(context);
  if (!path) {
    return bad("Mã khu vực hoặc loại xe không hợp lệ.");
  }
  const result = await fetchOpsUpstream({ method: "DELETE", path });
  return jsonFromOpsUpstream(result);
}
