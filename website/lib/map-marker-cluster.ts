import type { MapMarker } from "@/components/ui/real-map-view";

const KIND_PRIORITY: Record<string, number> = {
  warning: 0,
  driver: 1,
  pickup: 2,
  store: 3,
  hub: 4,
  dropoff: 5,
};

/**
 * Grid-cluster markers for dense ops maps.
 * Cells with 1 point stay as-is; cells with 2+ become one count bubble.
 */
export function clusterMapMarkers(
  markers: readonly MapMarker[],
  options?: { cellDegrees?: number; maxPoints?: number },
): MapMarker[] {
  const cellDegrees = options?.cellDegrees ?? 0.008;
  const maxPoints = options?.maxPoints ?? 80;
  const source = markers.slice(0, Math.max(maxPoints * 3, maxPoints));

  const buckets = new Map<string, MapMarker[]>();
  for (const marker of source) {
    const key = `${Math.floor(marker.lat / cellDegrees)}:${Math.floor(marker.lng / cellDegrees)}`;
    const bucket = buckets.get(key);
    if (bucket) {
      bucket.push(marker);
    } else {
      buckets.set(key, [marker]);
    }
  }

  const clustered: MapMarker[] = [];
  for (const [key, group] of buckets) {
    if (group.length === 1) {
      clustered.push(group[0]!);
      continue;
    }
    const lat = group.reduce((sum, item) => sum + item.lat, 0) / group.length;
    const lng = group.reduce((sum, item) => sum + item.lng, 0) / group.length;
    const top = [...group].sort(
      (a, b) =>
        (KIND_PRIORITY[a.type ?? "driver"] ?? 9) -
        (KIND_PRIORITY[b.type ?? "driver"] ?? 9),
    )[0]!;
    clustered.push({
      id: `cluster:${key}`,
      lat,
      lng,
      label: `${group.length} điểm`,
      type: top.type === "driver" ? "driver" : "hub",
      status: `${group.length} đối tượng trong vùng`,
      detail: group
        .slice(0, 4)
        .map((item) => item.label)
        .join(" · "),
    });
  }

  return clustered
    .sort(
      (a, b) =>
        (KIND_PRIORITY[a.type ?? "driver"] ?? 9) -
        (KIND_PRIORITY[b.type ?? "driver"] ?? 9),
    )
    .slice(0, maxPoints);
}
