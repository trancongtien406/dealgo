import { NextResponse } from "next/server";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import {
  jsonFromOpsUpstream,
  parsePositiveInt,
} from "@/lib/api/ops-bff-response";

const NEST_AUDIENCES = new Set([
  "ALL",
  "CUSTOMER",
  "DRIVER",
  "MERCHANT",
  "STAFF",
]);

const NEST_CHANNELS = new Set(["PUSH", "SMS", "EMAIL", "IN_APP"]);

type NestCampaign = {
  code: string;
  title: string;
  body: string;
  channel: string;
  audience: string;
  status: string;
  reached?: string;
  reachedCount?: number | null;
  schedule: string;
};

type CampaignItem = {
  code: string;
  voucher: string;
  name: string;
  condition: string;
  service: string;
  window: string;
  status: string;
  used: number;
  cap: number;
  owner: string;
};

function mapUiStatusToNestTab(status: string | undefined): string | undefined {
  switch (status) {
    case "ACTIVE":
    case "RUNNING":
      return "RUNNING";
    case "SCHEDULED":
    case "UPCOMING":
    case "PENDING":
      return "PENDING";
    case "ENDED":
    case "SENT":
      return "SENT";
    case "DRAFT":
      return "DRAFT";
    default:
      return undefined;
  }
}

function mapCampaignStatus(status: string): string {
  switch (status) {
    case "SENDING":
    case "APPROVED":
    case "RUNNING":
    case "ACTIVE":
      return "RUNNING";
    case "SENT":
    case "ENDED":
      return "ENDED";
    case "SCHEDULED":
    case "PENDING_APPROVAL":
    case "UPCOMING":
      return "UPCOMING";
    case "DRAFT":
    case "CANCELLED":
    case "REJECTED":
      return "DRAFT";
    default:
      return status;
  }
}

function mapCampaign(row: NestCampaign): CampaignItem {
  const reached = row.reachedCount ?? 0;
  return {
    code: row.code,
    voucher: row.code,
    name: row.title,
    condition: row.body.slice(0, 80) || "—",
    service: row.channel || "Push",
    window: row.schedule || "—",
    status: mapCampaignStatus(row.status),
    used: reached,
    cap: 0,
    owner: row.audience || "Ops",
  };
}

function parseNestAudience(raw: string | null): string | undefined {
  const audience = raw?.trim();
  if (!audience || audience === "ALL") {
    return undefined;
  }
  if (!NEST_AUDIENCES.has(audience)) {
    return undefined;
  }
  return audience;
}

function parseNestChannel(raw: string | null): string | undefined {
  const channel = raw?.trim();
  if (!channel || channel === "ALL") {
    return undefined;
  }
  if (!NEST_CHANNELS.has(channel)) {
    return undefined;
  }
  return channel;
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const page = parsePositiveInt(searchParams.get("page"), 1, 10_000);
  const limit = parsePositiveInt(searchParams.get("limit"), 10, 50);
  const q = searchParams.get("q")?.trim() || undefined;
  const tab = mapUiStatusToNestTab(searchParams.get("status")?.trim());
  const audience = parseNestAudience(searchParams.get("audience"));
  const channel = parseNestChannel(
    searchParams.get("channel") ?? searchParams.get("service"),
  );

  const result = await fetchOpsUpstream({
    path: "/v1/ops/notifications",
    searchParams: {
      page,
      limit,
      ...(q ? { q } : {}),
      ...(tab ? { tab } : {}),
      ...(audience ? { audience } : {}),
      ...(channel ? { channel } : {}),
    },
  });

  if (!result.ok) {
    return jsonFromOpsUpstream(result);
  }

  const upstream = result.data as {
    items?: NestCampaign[];
    total?: number;
    page?: number;
    limit?: number;
  };

  const items = (upstream.items ?? []).map(mapCampaign);

  return NextResponse.json({
    success: true,
    data: {
      items,
      total: upstream.total ?? items.length,
      page: upstream.page ?? page,
      limit: upstream.limit ?? limit,
    },
  });
}
