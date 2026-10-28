import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { badRequest, readJsonBody } from "@/lib/api/ops-bff-json";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import {
  isFoodCategoryCode,
  pickFoodCategoryBody,
} from "@/lib/api/ops-food-category-body";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ code: string }> };

const INVALID_CODE = "Mã danh mục không hợp lệ.";

export async function PATCH(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const { code } = await context.params;
  if (!isFoodCategoryCode(code)) {
    return badRequest(INVALID_CODE);
  }
  const body = pickFoodCategoryBody(await readJsonBody(request));
  if (!body.ok) {
    return badRequest(body.message);
  }
  const result = await fetchOpsUpstream({
    method: "PATCH",
    path: `/v1/ops/food-categories/${code}`,
    body: body.value,
  });
  return jsonFromOpsUpstream(result);
}

export async function DELETE(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const { code } = await context.params;
  if (!isFoodCategoryCode(code)) {
    return badRequest(INVALID_CODE);
  }
  const result = await fetchOpsUpstream({
    method: "DELETE",
    path: `/v1/ops/food-categories/${code}`,
  });
  return jsonFromOpsUpstream(result);
}
