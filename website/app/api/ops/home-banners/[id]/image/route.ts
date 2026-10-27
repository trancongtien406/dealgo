import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { badRequest, readJsonBody } from "@/lib/api/ops-bff-json";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import {
  HOME_BANNER_ID_RE,
  checkHomeBannerImageBody,
} from "@/lib/api/ops-home-banner-body";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

type RouteContext = { params: Promise<{ id: string }> };

export async function POST(request: Request, context: RouteContext) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const { id } = await context.params;
  if (!HOME_BANNER_ID_RE.test(id)) {
    return badRequest("Mã banner không hợp lệ.");
  }
  const body = checkHomeBannerImageBody(await readJsonBody(request));
  if (!body.ok) {
    return badRequest(body.message);
  }
  const result = await fetchOpsUpstream({
    method: "POST",
    path: `/v1/ops/home-banners/${id}/image`,
    body: body.value,
    timeoutMs: 30_000,
  });
  return jsonFromOpsUpstream(result);
}
