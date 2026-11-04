import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

/** Sweep pending top-ups against the PSP (bounded batch, safe to re-run). */
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
