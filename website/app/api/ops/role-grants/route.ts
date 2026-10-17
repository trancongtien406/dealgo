import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import {
  jsonFromOpsUpstream,
  parsePositiveInt,
} from "@/lib/api/ops-bff-response";

const ALLOWED_STATUS = new Set(["PENDING", "ACTIVE", "SUSPENDED"]);

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const statusRaw = searchParams.get("status")?.trim().toUpperCase();
  const status =
    statusRaw && ALLOWED_STATUS.has(statusRaw) ? statusRaw : "PENDING";
  const page = parsePositiveInt(searchParams.get("page"), 1, 10_000);
  const limit = parsePositiveInt(searchParams.get("limit"), 20, 50);

  const result = await fetchOpsUpstream({
    path: "/v1/ops/role-grants",
    searchParams: {
      status,
      page,
      limit,
    },
  });
  return jsonFromOpsUpstream(result);
}
