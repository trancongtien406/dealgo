"use client";

import dynamic from "next/dynamic";
import type { ComponentProps } from "react";

export type {
  MapCoordinate,
  MapMarker,
  MapPolygon,
  RealMapViewProps,
} from "@/components/ui/real-map-view";

export const LazyRealMapView = dynamic(
  () => import("@/components/ui/real-map-view").then((mod) => mod.RealMapView),
  {
    ssr: false,
    loading: () => (
      <div
        className="animate-pulse rounded-xl bg-canvas"
        style={{ minHeight: 280 }}
        aria-hidden="true"
      />
    ),
  },
);

export type LazyRealMapViewProps = ComponentProps<typeof LazyRealMapView>;
