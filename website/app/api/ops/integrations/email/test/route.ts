import { forwardOpsJsonMutation } from "@/lib/api/ops-forward-json";

export async function POST(request: Request) {
  return forwardOpsJsonMutation(request, "POST", "/v1/ops/integrations/email/test");
}
