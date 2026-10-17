import { NextResponse } from "next/server";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import {
  jsonFromOpsUpstream,
  parsePositiveInt,
} from "@/lib/api/ops-bff-response";
import { formatZoneRuleValue } from "@/features/zones/mappers";
import type { PriceStatus, ZoneRule } from "@/features/zones/types";

/** Nest OpsZonesRulesQueryDto max; never forward above this. */
const NEST_RULES_LIMIT = 50;

type NestRule = {
  code: string;
  name: string;
  service: string;
  zone: string;
  status: string;
  value: string;
  unit: string;
  updatedAt: string | null;
};

function mapRule(row: NestRule): ZoneRule {
  return {
    code: row.code,
    name: row.name,
    service: row.service,
    zone: row.zone,
    status: (row.status === "ACTIVE" ? "ACTIVE" : "DRAFT") as PriceStatus,
    value: row.value,
    unit: row.unit,
    displayValue: formatZoneRuleValue(row.value, row.unit),
    updatedAt: row.updatedAt,
  };
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const page = parsePositiveInt(searchParams.get("page"), 1, 10_000);
  const limit = parsePositiveInt(searchParams.get("limit"), 10, 50);
  const q = searchParams.get("q")?.trim() || undefined;

  const nestLimit = Math.min(NEST_RULES_LIMIT, 50);

  const result = await fetchOpsUpstream({
    path: "/v1/ops/zones/rules",
    searchParams: {
      page: 1,
      limit: nestLimit,
      ...(q ? { q } : {}),
    },
  });

  if (!result.ok) {
    return jsonFromOpsUpstream(result);
  }

  const upstream = result.data as {
    items?: NestRule[];
    total?: number;
  };

  let items = (upstream.items ?? []).map(mapRule);

  const service = searchParams.get("service")?.trim();
  const status = searchParams.get("status")?.trim();

  if (service && service !== "ALL") {
    items = items.filter((row) => row.service === service);
  }
  if (status && status !== "ALL") {
    items = items.filter((row) => row.status === status);
  }

  const total = items.length;
  const start = (page - 1) * limit;
  const paged = items.slice(start, start + limit);

  return NextResponse.json({
    success: true,
    data: {
      items: paged,
      total,
      page,
      limit,
    },
  });
}
