import { NextResponse } from "next/server";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import {
  jsonFromOpsUpstream,
  parsePositiveInt,
} from "@/lib/api/ops-bff-response";

function formatDiscountCondition(item: {
  discountType: string;
  discountValue: number;
  maxDiscountAmount?: number;
  minOrderAmount: number;
}): string {
  let discountStr = "";
  if (item.discountType === "FIXED_AMOUNT") {
    discountStr = `Giảm ${item.discountValue.toLocaleString("vi-VN")}đ`;
  } else if (item.discountType === "PERCENTAGE") {
    discountStr = `Giảm ${item.discountValue}%`;
    if (item.maxDiscountAmount) {
      discountStr += ` (tối đa ${item.maxDiscountAmount.toLocaleString("vi-VN")}đ)`;
    }
  } else if (item.discountType === "DELIVERY_DISCOUNT") {
    discountStr = `Freeship ${item.discountValue.toLocaleString("vi-VN")}đ`;
  }

  const minOrderStr =
    item.minOrderAmount > 0
      ? `Đơn từ ${item.minOrderAmount.toLocaleString("vi-VN")}đ`
      : "Mọi đơn";

  return `${discountStr} · ${minOrderStr}`;
}

function formatServiceLabel(type: string): string {
  switch (type) {
    case "RIDE":
      return "Xe 2 bánh";
    case "FOOD":
      return "Giao đồ ăn";
    default:
      return "Toàn hệ thống";
  }
}

function formatDateWindow(start: string, end: string): string {
  try {
    const s = new Date(start);
    const e = new Date(end);
    const sStr = `${s.getDate().toString().padStart(2, "0")}/${(s.getMonth() + 1).toString().padStart(2, "0")}`;
    const eStr = `${e.getDate().toString().padStart(2, "0")}/${(e.getMonth() + 1).toString().padStart(2, "0")}/${e.getFullYear()}`;
    return `${sStr} — ${eStr}`;
  } catch {
    return "Không giới hạn";
  }
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const page = parsePositiveInt(searchParams.get("page"), 1, 10_000);
  const limit = parsePositiveInt(searchParams.get("limit"), 10, 100);
  const q = searchParams.get("q")?.trim() || undefined;
  const status = searchParams.get("status")?.trim() || undefined;
  const serviceType = searchParams.get("serviceType")?.trim() || searchParams.get("channel")?.trim() || undefined;
  const audience = searchParams.get("audience")?.trim() || undefined;

  const result = await fetchOpsUpstream({
    path: "/v1/ops/promotions",
    searchParams: {
      page,
      limit,
      ...(q ? { q } : {}),
      ...(status && status !== "ALL" ? { status } : {}),
      ...(serviceType && serviceType !== "ALL" ? { serviceType } : {}),
      ...(audience && audience !== "ALL" ? { audience } : {}),
    },
  });

  if (!result.ok) {
    return jsonFromOpsUpstream(result);
  }

  const upstream = result.data as {
    items?: Array<{
      id: string;
      code: string;
      name: string;
      description: string;
      serviceType: string;
      discountType: string;
      discountValue: number;
      maxDiscountAmount?: number;
      minOrderAmount: number;
      totalBudget: number;
      usedBudget: number;
      usageLimit: number;
      usedCount: number;
      userLimit: number;
      targetAudience: string;
      status: string;
      startDate: string;
      endDate: string;
      sponsor: string;
      createdAt: string;
    }>;
    total?: number;
    page?: number;
    limit?: number;
    kpi?: {
      totalCampaigns: number;
      activeCount: number;
      scheduledCount: number;
      endedCount: number;
      totalBudgetCommitted: number;
      totalBudgetSpent: number;
      totalRedemptions: number;
    };
  };

  const rawItems = upstream.items ?? [];
  const items = rawItems.map((raw) => ({
    id: raw.id,
    code: raw.code,
    voucher: raw.code,
    name: raw.name,
    description: raw.description,
    condition: formatDiscountCondition(raw),
    service: formatServiceLabel(raw.serviceType),
    serviceType: raw.serviceType,
    discountType: raw.discountType,
    discountValue: raw.discountValue,
    maxDiscountAmount: raw.maxDiscountAmount,
    minOrderAmount: raw.minOrderAmount,
    totalBudget: raw.totalBudget,
    usedBudget: raw.usedBudget,
    usageLimit: raw.usageLimit,
    usedCount: raw.usedCount,
    used: raw.usedCount,
    cap: raw.usageLimit,
    window: formatDateWindow(raw.startDate, raw.endDate),
    startDate: raw.startDate,
    endDate: raw.endDate,
    status: raw.status,
    owner: raw.sponsor === "PLATFORM" ? "Nền tảng DealGo" : raw.sponsor === "MERCHANT" ? "Đối tác quán ăn" : "Đồng tài trợ",
    targetAudience: raw.targetAudience,
    createdAt: raw.createdAt,
  }));

  return NextResponse.json({
    success: true,
    data: {
      items,
      total: upstream.total ?? items.length,
      page: upstream.page ?? page,
      limit: upstream.limit ?? limit,
      kpi: upstream.kpi,
    },
  });
}

export async function POST(request: Request) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, message: "Dữ liệu JSON không hợp lệ." },
      { status: 400 },
    );
  }

  const result = await fetchOpsUpstream({
    method: "POST",
    path: "/v1/ops/promotions",
    body,
  });

  return jsonFromOpsUpstream(result);
}
