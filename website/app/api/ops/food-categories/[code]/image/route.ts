import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { badRequest, readJsonBody } from "@/lib/api/ops-bff-json";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import {
  checkFoodCategoryImageBody,
  isFoodCategoryCode,
} from "@/lib/api/ops-food-category-body";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ code: string }> };

export async function POST(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const { code } = await context.params;
  if (!isFoodCategoryCode(code)) {
    return badRequest("Mã danh mục không hợp lệ.");
  }
  const body = checkFoodCategoryImageBody(await readJsonBody(request));
  if (!body.ok) {
    return badRequest(body.message);
  }
  const result = await fetchOpsUpstream({
    method: "POST",
    path: `/v1/ops/food-categories/${code}/image`,
    body: body.value,
    timeoutMs: 30_000,
  });
  return jsonFromOpsUpstream(result);
}
