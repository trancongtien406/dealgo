import { NextResponse } from "next/server";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

/** Zone form place lookup → Nest GET /v1/ops/places/search (zones.write). */
export async function GET(request: Request) {
  const url = new URL(request.url);
  const q = url.searchParams.get("q")?.trim() ?? "";
  if (q.length < 2 || q.length > 120) {
    return NextResponse.json(
      { success: false, message: "Nhập 2–120 ký tự để tìm địa điểm." },
      { status: 400 },
    );
  }
  const searchParams: Record<string, string | undefined> = { q, limit: "6" };
  const lat = url.searchParams.get("lat");
  const lng = url.searchParams.get("lng");
  if (lat && lng) {
    searchParams.lat = lat;
    searchParams.lng = lng;
  }
  const result = await fetchOpsUpstream({
    path: "/v1/ops/places/search",
    searchParams,
  });
  return jsonFromOpsUpstream(result);
}
