import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { forwardOpsJsonMutation } from "@/lib/api/ops-forward-json";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

const PATH = "/v1/ops/integrations/email";

export async function GET() {
  return jsonFromOpsUpstream(await fetchOpsUpstream({ path: PATH }));
}

export async function PUT(request: Request) {
  return forwardOpsJsonMutation(request, "PUT", PATH);
}
