import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

/** Runs provider status reconciliation now (same idempotent job as the worker). */
export async function POST(request: Request) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const result = await fetchOpsUpstream({ method: "POST", path: "/v1/ops/payment-intents/reconcile", body: {} });
  return jsonFromOpsUpstream(result);
}
