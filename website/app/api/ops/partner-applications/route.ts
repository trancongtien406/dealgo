import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import { jsonFromOpsUpstream } from "@/lib/api/ops-bff-response";

const ALLOWED_STATUS = new Set(["DRAFT", "SUBMITTED", "APPROVED", "REJECTED"]);

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const status = searchParams.get("status")?.trim().toUpperCase();
  const page = searchParams.get("page")?.trim();
  const limit = searchParams.get("limit")?.trim();
  const q = searchParams.get("q")?.trim();

  const role = searchParams.get("role")?.trim().toUpperCase();

  const searchParamsOut: Record<string, string | undefined> = {};
  if (status && ALLOWED_STATUS.has(status)) {
    searchParamsOut.status = status;
  }
  if (role && (role === "DRIVER" || role === "MERCHANT")) {
    searchParamsOut.role = role;
  }
  if (page) {
    searchParamsOut.page = page;
  }
  if (limit) {
    searchParamsOut.limit = limit;
  }
  if (q) {
    searchParamsOut.q = q;
  }

  const result = await fetchOpsUpstream({
    path: "/v1/ops/partner-applications",
    searchParams: searchParamsOut,
  });
  return jsonFromOpsUpstream(result);
}
