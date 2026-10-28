import { jsonFromOpsUpstream, parsePositiveInt } from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

const STATUSES = new Set(["CREATED", "PENDING_REDIRECT", "CAPTURED", "FAILED", "EXPIRED", "REFUND_PENDING", "REFUNDED"]);
const PROVIDERS = new Set(["momo", "zalopay", "vnpay", "shopeepay", "card", "applepay", "wallet"]);
const ENTITY_TYPES = new Set(["RIDE", "FOOD_ORDER"]);

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const limit = parsePositiveInt(searchParams.get("limit"), 50, 200);
  const status = searchParams.get("status")?.trim();
  const provider = searchParams.get("provider")?.trim();
  const entityType = searchParams.get("entityType")?.trim();
  const q = searchParams.get("q")?.trim().slice(0, 80);
  const result = await fetchOpsUpstream({
    path: "/v1/ops/payment-intents",
    searchParams: {
      limit,
      ...(status && STATUSES.has(status) ? { status } : {}),
      ...(provider && PROVIDERS.has(provider) ? { provider } : {}),
      ...(entityType && ENTITY_TYPES.has(entityType) ? { entityType } : {}),
      ...(q ? { q } : {}),
    },
  });
  return jsonFromOpsUpstream(result);
}
