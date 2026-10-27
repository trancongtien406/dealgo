import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { badRequest, readJsonBody } from "@/lib/api/ops-bff-json";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { pickHomeBannerBody } from "@/lib/api/ops-home-banner-body";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

export async function GET() {
  const result = await fetchOpsUpstream({ path: "/v1/ops/home-banners" });
  return jsonFromOpsUpstream(result);
}

export async function POST(request: Request) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  const body = pickHomeBannerBody(await readJsonBody(request));
  if (!body.ok) {
    return badRequest(body.message);
  }
  const result = await fetchOpsUpstream({
    method: "POST",
    path: "/v1/ops/home-banners",
    body: body.value,
  });
  return jsonFromOpsUpstream(result);
}
