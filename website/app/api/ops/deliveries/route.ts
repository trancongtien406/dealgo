import { NextResponse } from "next/server";
import { fetchOpsUpstream } from "@/lib/api/ops-upstream";
import {
  jsonFromOpsUpstream,
  parsePositiveInt,
} from "@/lib/api/ops-bff-response";
import { serviceRegionLabel } from "@/lib/service-region-labels";
import { fetchOpsPeople, type OpsPeopleMap } from "@/lib/api/ops-people";

type NestFoodStatus =
  | "PLACED"
  | "PREPARING"
  | "READY"
  | "ASSIGNED"
  | "PICKED_UP"
  | "DELIVERED"
  | "FAILED"
  | "CANCELLED";

type NestFoodOrder = {
  id: string;
  customerId: string;
  storeId: string;
  storeName?: string | null;
  serviceRegionCode?: string | null;
  status: NestFoodStatus;
  deliveryFareVnd: number;
  totalVnd: number;
  dropoff?: { lat?: number; lng?: number; label?: string };
  pickup?: { lat?: number; lng?: number; label?: string | null } | null;
  assignedDriverId: string | null;
  lines?: Array<{ name: string; quantity: number }>;
};

type GeoPoint = { lat: number; lng: number };

function point(
  value: { lat?: number; lng?: number } | null | undefined,
): GeoPoint | null {
  if (!value) return null;
  const { lat, lng } = value;
  return typeof lat === "number" &&
    typeof lng === "number" &&
    Number.isFinite(lat) &&
    Number.isFinite(lng)
    ? { lat, lng }
    : null;
}

type DeliveryStatus =
  "WAITING_DRIVER" | "PICKED_UP" | "DELIVERING" | "COMPLETED" | "FAILED";

type DeliveryItem = {
  code: string;
  sender: string;
  route: string;
  cargo: string;
  fee: number;
  driver: string | null;
  status: DeliveryStatus;
  time: string;
  regionLabel: string;
  pickupPoint: GeoPoint | null;
  dropoffPoint: GeoPoint | null;
};

const INFLIGHT_STATUSES: NestFoodStatus[] = [
  "PLACED",
  "PREPARING",
  "READY",
  "ASSIGNED",
  "PICKED_UP",
];

const UI_TO_NEST: Record<string, NestFoodStatus | NestFoodStatus[]> = {
  PENDING: ["PLACED", "PREPARING", "READY"],
  PICKED_UP: "PICKED_UP",
  DELIVERING: "ASSIGNED",
  DONE: "DELIVERED",
  CANCELLED: ["FAILED", "CANCELLED"],
};

function mapDeliveryStatus(status: NestFoodStatus): DeliveryStatus {
  switch (status) {
    case "PLACED":
    case "PREPARING":
    case "READY":
      return "WAITING_DRIVER";
    case "ASSIGNED":
      return "DELIVERING";
    case "PICKED_UP":
      return "PICKED_UP";
    case "DELIVERED":
      return "COMPLETED";
    case "FAILED":
    case "CANCELLED":
      return "FAILED";
    default:
      return "WAITING_DRIVER";
  }
}

function shortId(id: string): string {
  return id.slice(0, 8);
}

function mapOrder(order: NestFoodOrder, people: OpsPeopleMap): DeliveryItem {
  const cargo =
    order.lines && order.lines.length > 0
      ? order.lines.map((l) => `${l.name} x${l.quantity}`).join(", ")
      : "Đơn đồ ăn";
  const storeLabel =
    order.storeName?.trim() || `CH · ${shortId(order.storeId)}`;
  return {
    code: order.id,
    sender: storeLabel,
    route: order.dropoff?.label?.trim() || "Điểm giao",
    cargo,
    fee: order.deliveryFareVnd ?? order.totalVnd ?? 0,
    driver: order.assignedDriverId
      ? people[order.assignedDriverId]?.displayName?.trim() ||
        `TX · ${shortId(order.assignedDriverId)}`
      : null,
    status: mapDeliveryStatus(order.status),
    time: "—",
    regionLabel:
      serviceRegionLabel(order.serviceRegionCode) ??
      order.serviceRegionCode ??
      "—",
    pickupPoint: point(order.pickup),
    dropoffPoint: point(order.dropoff),
  };
}

function nestStatusesForUi(
  uiStatus: string | undefined,
): NestFoodStatus[] | NestFoodStatus | undefined {
  if (!uiStatus || uiStatus === "ALL") {
    return INFLIGHT_STATUSES;
  }
  return UI_TO_NEST[uiStatus];
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const page = parsePositiveInt(searchParams.get("page"), 1, 10_000);
  const limit = parsePositiveInt(searchParams.get("limit"), 10, 50);
  const q = searchParams.get("q")?.trim() || undefined;
  const uiStatus = searchParams.get("status")?.trim() || undefined;

  const nestStatus = nestStatusesForUi(uiStatus);

  const upstreamParams: Record<string, string | number | undefined> = {
    page,
    limit,
    ...(q ? { q } : {}),
  };

  if (Array.isArray(nestStatus)) {
    upstreamParams.statuses = nestStatus.join(",");
  } else if (nestStatus) {
    upstreamParams.status = nestStatus;
  }

  const result = await fetchOpsUpstream({
    path: "/v1/ops/food-orders",
    searchParams: upstreamParams,
  });

  if (!result.ok) {
    return jsonFromOpsUpstream(result);
  }

  const upstream = result.data as {
    items?: NestFoodOrder[];
    total?: number;
    page?: number;
    limit?: number;
  };

  const nestItems = upstream.items ?? [];
  const people = await fetchOpsPeople(
    nestItems.map((order) => order.assignedDriverId),
  );
  const items = nestItems.map((order) => mapOrder(order, people));

  return NextResponse.json({
    success: true,
    data: {
      items,
      total: upstream.total ?? items.length,
      page: upstream.page ?? page,
      limit,
    },
  });
}
