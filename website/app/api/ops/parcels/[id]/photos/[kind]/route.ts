import { NextResponse } from "next/server";
import { isUuid } from "@/lib/api/ops-bff-guards";
import { binaryFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstreamBinary } from "@/lib/api/ops-upstream";
import { isParcelPhotoKind } from "@/features/parcels/mappers";

type RouteContext = { params: Promise<{ id: string; kind: string }> };

/** Streams one parcel proof photo (ops session only). */
export async function GET(_request: Request, context: RouteContext) {
  const { id, kind } = await context.params;
  if (!isUuid(id) || !isParcelPhotoKind(kind)) {
    return NextResponse.json({ success: false, message: "Ảnh không hợp lệ." }, { status: 400 });
  }
  return binaryFromOpsUpstream(await fetchOpsUpstreamBinary(`/v1/ops/parcels/${id}/photos/${kind}`));
}
