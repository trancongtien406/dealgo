import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import {
  jsonFromOpsUpstream,
  parsePositiveInt,
} from "@/lib/api/ops-bff-response";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

const TABS = new Set(["ALL", "RUNNING", "SENT", "PENDING", "DRAFT"]);
const CHANNELS = new Set(["PUSH", "SMS", "EMAIL", "IN_APP"]);
const AUDIENCES = new Set(["ALL", "CUSTOMER", "DRIVER", "MERCHANT", "STAFF"]);

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const page = parsePositiveInt(searchParams.get("page"), 1, 10_000);
  const limit = parsePositiveInt(searchParams.get("limit"), 10, 50);
  const tabRaw = searchParams.get("tab")?.trim().toUpperCase() ?? "";

  const result = await fetchOpsUpstream({
    path: "/v1/ops/notifications",
    searchParams: {
      page,
      limit,
      q: searchParams.get("q")?.trim() || undefined,
      tab: TABS.has(tabRaw) ? tabRaw : undefined,
      channel: searchParams.get("channel")?.trim() || undefined,
      audience: searchParams.get("audience")?.trim() || undefined,
    },
  });
  return jsonFromOpsUpstream(result);
}

export async function POST(request: Request) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }

  const parsed = await readCreateBody(request);
  if (!parsed.ok) {
    return NextResponse.json(
      { success: false, message: parsed.message },
      { status: parsed.status },
    );
  }

  const result = await fetchOpsUpstream({
    method: "POST",
    path: "/v1/ops/notifications",
    body: parsed.body,
  });
  return jsonFromOpsUpstream(result);
}

type CreateBody = {
  title: string;
  body: string;
  channels: string[];
  audience: string;
  audienceNote?: string | null;
  isAutomatic?: boolean;
  scheduledAt?: string | null;
  reason?: string;
};

async function readCreateBody(
  request: Request,
): Promise<
  | { ok: true; body: CreateBody }
  | { ok: false; status: number; message: string }
> {
  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().includes("application/json")) {
    return { ok: false, status: 415, message: "Yêu cầu không hợp lệ." };
  }
  let json: unknown;
  try {
    json = await request.json();
  } catch {
    return { ok: false, status: 400, message: "Yêu cầu không hợp lệ." };
  }
  if (typeof json !== "object" || json === null) {
    return { ok: false, status: 400, message: "Yêu cầu không hợp lệ." };
  }
  const raw = json as Record<string, unknown>;
  const title = typeof raw.title === "string" ? raw.title.trim() : "";
  const body = typeof raw.body === "string" ? raw.body.trim() : "";
  if (title.length < 3 || title.length > 160) {
    return { ok: false, status: 400, message: "Tiêu đề phải từ 3–160 ký tự." };
  }
  if (body.length < 3 || body.length > 2000) {
    return {
      ok: false,
      status: 400,
      message: "Nội dung phải từ 3–2000 ký tự.",
    };
  }
  if (!Array.isArray(raw.channels) || raw.channels.length < 1) {
    return { ok: false, status: 400, message: "Chọn ít nhất một kênh." };
  }
  const channels = raw.channels
    .filter((c): c is string => typeof c === "string")
    .map((c) => c.trim().toUpperCase())
    .filter((c) => CHANNELS.has(c));
  if (channels.length < 1 || channels.length > 4) {
    return { ok: false, status: 400, message: "Kênh không hợp lệ." };
  }
  const audience =
    typeof raw.audience === "string" ? raw.audience.trim().toUpperCase() : "";
  if (!AUDIENCES.has(audience)) {
    return { ok: false, status: 400, message: "Đối tượng không hợp lệ." };
  }
  const audienceNote =
    typeof raw.audienceNote === "string"
      ? raw.audienceNote.trim().slice(0, 160) || null
      : null;
  const isAutomatic = raw.isAutomatic === true;
  const scheduledAt =
    typeof raw.scheduledAt === "string" && raw.scheduledAt.trim()
      ? raw.scheduledAt.trim()
      : null;
  const reason =
    typeof raw.reason === "string" && raw.reason.trim().length >= 3
      ? raw.reason.trim().slice(0, 500)
      : undefined;

  return {
    ok: true,
    body: {
      title,
      body,
      channels,
      audience,
      audienceNote,
      isAutomatic,
      scheduledAt,
      ...(reason ? { reason } : {}),
    },
  };
}
