import type { OpsIconName } from "@/components/ui/ops-icons";
import type { OpsActivityItem } from "@/components/ui/ops-activity-feed";
import type { StatusTone } from "@/lib/admin-format";
import { formatOpsClock, formatOpsRelative } from "@/lib/ops-time";

export type NestOpsActivityItem = {
  kind: "ride" | "food" | "exception";
  title: string;
  detail: string;
  at: string;
  tone?: string;
};

const kindIcon: Record<NestOpsActivityItem["kind"], OpsIconName> = {
  ride: "car",
  food: "utensils",
  exception: "alert",
};

const kindTone: Record<NestOpsActivityItem["kind"], StatusTone> = {
  ride: "brand",
  food: "food",
  exception: "danger",
};

function resolveTone(
  kind: NestOpsActivityItem["kind"],
  tone?: string,
): StatusTone {
  if (
    tone === "danger" ||
    tone === "food" ||
    tone === "brand" ||
    tone === "success" ||
    tone === "delivery"
  ) {
    return tone;
  }
  return kindTone[kind];
}

export function mapOpsActivity(
  items: readonly NestOpsActivityItem[],
  mode: "relative" | "clock" = "relative",
): OpsActivityItem[] {
  return items.map((item, index) => ({
    id: `${item.kind}-${item.at}-${index}`,
    title: item.title,
    detail: item.detail,
    time:
      mode === "clock" ? formatOpsClock(item.at) : formatOpsRelative(item.at),
    tone: resolveTone(item.kind, item.tone),
    icon: kindIcon[item.kind],
  }));
}
