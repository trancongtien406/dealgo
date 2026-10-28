import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { badRequest, readJsonBody } from "@/lib/api/ops-bff-json";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { checkFoodCategoryReorderBody } from "@/lib/api/ops-food-category-body";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

export async function POST(request: Request) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const body = checkFoodCategoryReorderBody(await readJsonBody(request));
  if (!body.ok) {
    return badRequest(body.message);
  }
  const result = await fetchOpsUpstream({
    method: "POST",
    path: "/v1/ops/food-categories/reorder",
    body: body.value,
  });
  return jsonFromOpsUpstream(result);
}
