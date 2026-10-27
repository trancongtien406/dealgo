import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";

const DAY = /^\d{4}-\d{2}-\d{2}$/;

function day(value: string | null): string | undefined {
  return value && DAY.test(value) ? value : undefined;
}

/** Proxies Nest GET /v1/ops/reports?from&to (Vietnam business days, `to` inclusive). */
export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const result = await fetchOpsUpstream({
    path: "/v1/ops/reports",
    searchParams: {
      from: day(searchParams.get("from")),
      to: day(searchParams.get("to")),
    },
  });
  return jsonFromOpsUpstream(result);
}
