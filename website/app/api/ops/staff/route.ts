import { NextResponse } from "next/server";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import {
  jsonFromOpsUpstream,
  parsePositiveInt,
} from "@/lib/api/ops-bff-response";
import { formatOpsDate } from "@/lib/ops-time";

export type PersonItem = {
  id: string;
  /** Server staffRole code (ADMIN = has Admin password login). */
  roleCode: string;
  superAdmin: boolean;
  name: string;
  email: string;
  letters: string;
  role: string;
  scope: string;
  status: "ACTIVE" | "INVITED" | "SUSPENDED";
  seen: string;
};

type NestStaffRow = {
  id?: string;
  superAdmin?: boolean;
  displayName?: string;
  email?: string;
  createdAt?: string;
  role?: string;
  scope?: string;
  grants?: Array<{ role?: string; status?: string }>;
};

const STAFF_ROLE_LABEL: Record<string, string> = {
  ADMIN: "Quản trị",
  OPS: "Vận hành",
  SUPPORT: "CSKH",
  FINANCE: "Tài chính",
};

const STAFF_SCOPE_LABEL: Record<string, string> = {
  NATIONAL: "Toàn quốc",
  CITY: "Theo thành phố",
  ZONE: "Theo vùng",
};

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const page = parsePositiveInt(searchParams.get("page"), 1, 10_000);
  const limit = parsePositiveInt(searchParams.get("limit"), 10, 50);

  const q = searchParams.get("q")?.trim() || undefined;
  const status = searchParams.get("status")?.trim() || undefined;
  const role = searchParams.get("role")?.trim() || undefined;
  const scope = searchParams.get("scope")?.trim() || undefined;

  const result = await fetchOpsUpstream({
    path: "/v1/ops/staff",
    searchParams: {
      page,
      limit,
      ...(q ? { q } : {}),
      ...(status && status !== "ALL" ? { status } : {}),
      ...(role && role !== "ALL" ? { role } : {}),
      ...(scope && scope !== "ALL" ? { scope } : {}),
    },
  });

  if (!result.ok) {
    return jsonFromOpsUpstream(result);
  }

  const upstreamData = result.data as {
    items?: NestStaffRow[];
    total?: number;
    page?: number;
    limit?: number;
    counts?: { active?: number; pending?: number; suspended?: number };
  };
  const items: PersonItem[] = (upstreamData.items ?? []).map((u) => {
    const words = (u.displayName || u.email || "Staff")
      .split(/\s+/)
      .filter(Boolean);
    const letters = (
      words.length >= 2
        ? words[0][0] + words[1][0]
        : (u.displayName || "ST").slice(0, 2)
    ).toUpperCase();
    const grant = u.grants?.[0]?.status ?? "ACTIVE";
    const roleCode = (u.role || "OPS").toUpperCase();
    const scopeCode = (u.scope || "NATIONAL").toUpperCase();
    return {
      id: u.id ?? "",
      roleCode,
      superAdmin: u.superAdmin === true,
      name: u.displayName || u.email || "Staff",
      email: u.email || "staff@dealgo.vn",
      letters,
      role: STAFF_ROLE_LABEL[roleCode] ?? roleCode,
      scope: STAFF_SCOPE_LABEL[scopeCode] ?? scopeCode,
      status:
        grant === "ACTIVE"
          ? "ACTIVE"
          : grant === "SUSPENDED"
            ? "SUSPENDED"
            : "INVITED",
      seen: u.createdAt ? formatOpsDate(u.createdAt) : "Hôm nay",
    };
  });

  return NextResponse.json({
    success: true,
    data: {
      items,
      total: upstreamData.total ?? items.length,
      page: upstreamData.page ?? page,
      limit: upstreamData.limit ?? limit,
      ...(upstreamData.counts
        ? {
            counts: {
              active: upstreamData.counts.active ?? 0,
              pending: upstreamData.counts.pending ?? 0,
              suspended: upstreamData.counts.suspended ?? 0,
            },
          }
        : {}),
    },
  });
}
