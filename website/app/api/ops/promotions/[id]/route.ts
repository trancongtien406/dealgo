import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";

export async function GET(
  _request: Request,
  props: { params: Promise<{ id: string }> },
) {
  const { id } = await props.params;
  const result = await fetchOpsUpstream({
    path: `/v1/ops/promotions/${encodeURIComponent(id)}`,
  });

  return jsonFromOpsUpstream(result);
}
