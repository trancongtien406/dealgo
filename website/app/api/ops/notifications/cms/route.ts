import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const kind = searchParams.get("kind")?.trim();

  const result = await fetchOpsUpstream({
    path: "/v1/ops/notifications/cms",
    searchParams: {
      kind: kind && kind !== "ALL" && kind !== "Tất cả" ? kind : undefined,
      q: searchParams.get("q")?.trim() || undefined,
    },
  });
  return jsonFromOpsUpstream(result);
}

export async function POST(request: Request) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }
  let body: unknown = {};
  try {
    body = await request.json();
  } catch {
    body = {};
  }

  const result = await fetchOpsUpstream({
    method: "POST",
    path: "/v1/ops/notifications/cms",
    body,
  });
  return jsonFromOpsUpstream(result);
}
