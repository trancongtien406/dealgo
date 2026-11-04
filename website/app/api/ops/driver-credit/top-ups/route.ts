import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import {
  jsonFromOpsUpstream,
  parsePositiveInt,
} from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

const STATUSES = new Set([
  "PENDING",
  "PAID",
  "EXPIRED",
  "CANCELLED",
  "REFUND_PENDING",
  "REFUNDED",
  "FAILED",
]);

/** Driver prepaid top-ups (DEC-PROD-093), newest first. */
export async function GET(request: Request) {
  const url = new URL(request.url);
  const params = new URLSearchParams();
  const status = url.searchParams.get("status");
  if (status && STATUSES.has(status)) {
    params.set("status", status);
  }
  const driverId = url.searchParams.get("driverId");
  if (driverId) {
    params.set("driverId", driverId);
  }
  params.set(
    "limit",
    String(parsePositiveInt(url.searchParams.get("limit"), 50, 100)),
  );
  const result = await fetchOpsUpstream({
    path: `/v1/ops/driver-credit/top-ups?${params.toString()}`,
  });
  return jsonFromOpsUpstream(result);
}

/** Sweep pending top-ups against the PSP (bounded batch). */
export async function POST(request: Request) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const result = await fetchOpsUpstream({
    method: "POST",
    path: "/v1/ops/driver-credit/reconcile",
  });
  return jsonFromOpsUpstream(result);
}
