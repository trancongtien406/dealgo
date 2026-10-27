import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { badRequest, readJsonBody } from "@/lib/api/ops-bff-json";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import {
  HOME_BANNER_ID_RE,
  pickHomeBannerBody,
} from "@/lib/api/ops-home-banner-body";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ id: string }> };

const INVALID_ID = "Mã banner không hợp lệ.";

export async function PATCH(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const { id } = await context.params;
  if (!HOME_BANNER_ID_RE.test(id)) {
    return badRequest(INVALID_ID);
  }
  const body = pickHomeBannerBody(await readJsonBody(request));
  if (!body.ok) {
    return badRequest(body.message);
  }
  const result = await fetchOpsUpstream({
    method: "PATCH",
    path: `/v1/ops/home-banners/${id}`,
    body: body.value,
  });
  return jsonFromOpsUpstream(result);
}

export async function DELETE(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const { id } = await context.params;
  if (!HOME_BANNER_ID_RE.test(id)) {
    return badRequest(INVALID_ID);
  }
  const result = await fetchOpsUpstream({
    method: "DELETE",
    path: `/v1/ops/home-banners/${id}`,
  });
  return jsonFromOpsUpstream(result);
}
