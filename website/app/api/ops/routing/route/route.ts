import { NextResponse } from "next/server";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";

const LIMITS = { fromLat: 90, fromLng: 180, toLat: 90, toLng: 180 } as const;

/** DEC-PROD-045: Admin map routes go through Nest's configured provider, never the browser. */
export async function GET(request: Request) {
  const search = new URL(request.url).searchParams;
  const params = new URLSearchParams();
  for (const [name, limit] of Object.entries(LIMITS)) {
    const raw = search.get(name);
    const value = raw === null || raw.trim() === "" ? Number.NaN : Number(raw);
    if (!Number.isFinite(value) || Math.abs(value) > limit) {
      return NextResponse.json(
        { success: false, message: "Toạ độ không hợp lệ." },
        { status: 400 },
      );
    }
    params.set(name, String(value));
  }
  const result = await fetchOpsUpstream({
    path: `/v1/ops/routing/route?${params.toString()}`,
  });
  return jsonFromOpsUpstream(result);
}
