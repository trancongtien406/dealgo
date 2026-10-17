"use client";

import { useMemo } from "react";
import {
  LazyRealMapView,
  type MapMarker,
} from "@/components/ui/lazy-real-map-view";
import { clusterMapMarkers } from "@/lib/map-marker-cluster";
import { DEFAULT_CENTER } from "@/lib/service-region-labels";

type MonitorLiveMapProps = {
  markers: readonly MapMarker[];
  regionLabel: string;
};

export function MonitorLiveMap({ markers, regionLabel }: MonitorLiveMapProps) {
  const displayMarkers = useMemo(
    () => clusterMapMarkers(markers, { cellDegrees: 0.01, maxPoints: 60 }),
    [markers],
  );

  const center = useMemo(() => {
    if (displayMarkers.length === 0) {
      return DEFAULT_CENTER;
    }
    const lat =
      displayMarkers.reduce((sum, marker) => sum + marker.lat, 0) /
      displayMarkers.length;
    const lng =
      displayMarkers.reduce((sum, marker) => sum + marker.lng, 0) /
      displayMarkers.length;
    return [lat, lng] as [number, number];
  }, [displayMarkers]);

  const clusterNote =
    markers.length > displayMarkers.length
      ? ` / ${markers.length} (đã gom cụm)`
      : "";

  return (
    <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm lg:col-span-3">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="min-w-0">
          <h2 className="text-base font-semibold text-ink">
            Bản đồ vận hành trực tiếp – {regionLabel}
          </h2>
          <p className="mt-1 text-sm text-muted">
            Hiển thị {displayMarkers.length}
            {clusterNote} điểm trên bản đồ
          </p>
        </div>
        <span className="inline-flex items-center gap-1.5 rounded-full bg-success/10 px-2.5 py-1 text-xs font-semibold text-success">
          <span
            aria-hidden="true"
            className="size-1.5 animate-pulse rounded-full bg-success"
          />
          Đang cập nhật
        </span>
      </div>
      <div className="mt-4">
        <LazyRealMapView
          center={center}
          zoom={12}
          height={360}
          markers={displayMarkers}
          showControls
          showAttribution
        />
      </div>
    </section>
  );
}
