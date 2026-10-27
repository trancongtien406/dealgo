import { NextResponse } from "next/server";
import { assertSameOriginMutation, isUuid } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ id: string }> };

export async function POST(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }

  const { id } = await context.params;
  if (!isUuid(id)) {
    return NextResponse.json(
      { success: false, message: "Mã hồ sơ không hợp lệ." },
      { status: 400 },
    );
  }

  const vehicleClassCode = await readVehicleClass(request);
  if (vehicleClassCode === false) {
    return NextResponse.json(
      { success: false, message: "Hạng xe không hợp lệ." },
      { status: 400 },
    );
  }

  const result = await fetchOpsUpstream({
    method: "POST",
    path: `/v1/ops/partner-applications/${id}/approve`,
    body: vehicleClassCode ? { vehicleClassCode } : {},
  });
  return jsonFromOpsUpstream(result);
}

/** DEC-PROD-048: optional ops-confirmed vehicle class; `false` = malformed. */
async function readVehicleClass(request: Request): Promise<string | null | false> {
  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().includes("application/json")) {
    return null;
  }
  let json: unknown;
  try {
    json = await request.json();
  } catch {
    return null;
  }
  const raw = (json as { vehicleClassCode?: unknown } | null)?.vehicleClassCode;
  if (raw === undefined || raw === null || raw === "") {
    return null;
  }
  if (typeof raw !== "string" || !/^[A-Z0-9_]{2,40}$/.test(raw)) {
    return false;
  }
  return raw;
}
