"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { OpsIcon } from "@/components/ui/ops-icons";
import { useTheme } from "@/components/theme/theme-provider";

export type MapCoordinate = [number, number]; // [lat, lng]

export type MapMarker = {
  id: string;
  lat: number;
  lng: number;
  label: string;
  type?: "driver" | "pickup" | "dropoff" | "warning" | "store" | "hub";
  status?: string;
  detail?: string;
  color?: string;
};

export type MapPolygon = {
  id: string;
  name: string;
  coords: MapCoordinate[];
  color?: string;
  fillColor?: string;
  active?: boolean;
};

export type RoadRouteOption = {
  id: string;
  name: string;
  coords: MapCoordinate[];
  distanceKm: number;
  durationMin: number;
  summary?: string;
  isFastest: boolean;
};

export type FetchRouteResult = {
  fastest: RoadRouteOption;
  alternatives: RoadRouteOption[];
};

export type RealMapViewProps = {
  center?: MapCoordinate; // default Da Nang [16.0544, 108.2022]
  zoom?: number; // default 13.5
  minZoom?: number;
  maxZoom?: number;
  height?: number | string;
  markers?: MapMarker[];
  polygons?: MapPolygon[];
  route?: MapCoordinate[];
  startLabel?: string;
  endLabel?: string;
  selectedPolygonId?: string;
  onPolygonSelect?: (id: string) => void;
  interactive?: boolean;
  className?: string;
  showControls?: boolean;
  showAttribution?: boolean;
  showDriverProgress?: boolean;
  routingMode?: "fastest" | "shortest";
  onRouteMetricsChange?: (metrics: {
    distanceKm: number;
    durationMin: number;
  }) => void;
};

// Coordinate math for Slippy Map tiles (Web Mercator EPSG:3857)
export function latLngToWorldPixel(lat: number, lng: number, zoom: number) {
  const n = 2 ** zoom;
  const x = ((lng + 180) / 360) * n * 256;
  const latRad = (lat * Math.PI) / 180;
  // Clamp latitude to avoid infinity at poles
  const clampedLatRad = Math.max(-1.4844, Math.min(1.4844, latRad));
  const y = ((1 - Math.asinh(Math.tan(clampedLatRad)) / Math.PI) / 2) * n * 256;
  return { x, y };
}

export function worldPixelToLatLng(
  x: number,
  y: number,
  zoom: number,
): MapCoordinate {
  const n = 2 ** zoom;
  const lng = (x / (n * 256)) * 360 - 180;
  const val = (1 - (2 * y) / (n * 256)) * Math.PI;
  const latRad = Math.atan(Math.sinh(val));
  const lat = (latRad * 180) / Math.PI;
  return [
    Math.max(-85, Math.min(85, lat)),
    ((((lng + 180) % 360) + 360) % 360) - 180,
  ];
}

/**
 * Mapbox is opt-in: only `NEXT_PUBLIC_MAPBOX_TOKEN` (website/.env.local) enables
 * it for tiles. Without it Admin maps use OSM/Carto tiles with attribution. Road routes
 * always come from Nest (`ROUTING_PROVIDER`, DEC-PROD-045); none → straight line.
 */
const MAPBOX_DEFAULT_TOKEN = process.env.NEXT_PUBLIC_MAPBOX_TOKEN?.trim() || "";

// Great-circle Haversine distance in meters
export function estimateHaversineDistance(coords: MapCoordinate[]): number {
  let total = 0;
  for (let i = 0; i < coords.length - 1; i++) {
    const [lat1, lon1] = coords[i];
    const [lat2, lon2] = coords[i + 1];
    const R = 6371000;
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLon = ((lon2 - lon1) * Math.PI) / 180;
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos((lat1 * Math.PI) / 180) *
        Math.cos((lat2 * Math.PI) / 180) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    total += R * c;
  }
  return total;
}

// In-memory route cache to avoid redundant API requests
const routeCache = new Map<string, FetchRouteResult>();

type ServerRoute = {
  coords: MapCoordinate[];
  distanceM: number;
  durationSec: number;
  summary: string;
};

/**
 * DEC-PROD-045 — road geometry comes from Nest (`GET /v1/ops/routing/route` via the
 * BFF), which uses the configured provider (ROUTING_PROVIDER). The browser never calls
 * OSRM/Mapbox Directions itself. Unconfigured or failing → `null` (straight line).
 */
async function fetchServerRoutes(
  start: MapCoordinate,
  end: MapCoordinate,
): Promise<ServerRoute[] | null> {
  const params = new URLSearchParams({
    fromLat: String(start[0]),
    fromLng: String(start[1]),
    toLat: String(end[0]),
    toLng: String(end[1]),
  });
  try {
    const res = await fetch(`/api/ops/routing/route?${params.toString()}`, {
      signal: AbortSignal.timeout(6000),
      credentials: "same-origin",
    });
    if (!res.ok) return null;
    const body = (await res.json()) as {
      data?: { available?: boolean; routes?: unknown };
    };
    if (!body?.data?.available || !Array.isArray(body.data.routes)) return null;
    const routes: ServerRoute[] = [];
    for (const raw of body.data.routes as Array<Partial<ServerRoute>>) {
      if (!Array.isArray(raw?.coords) || raw.coords.length < 2) continue;
      routes.push({
        coords: raw.coords,
        distanceM: typeof raw.distanceM === "number" ? raw.distanceM : 0,
        durationSec: typeof raw.durationSec === "number" ? raw.durationSec : 0,
        summary: typeof raw.summary === "string" ? raw.summary : "",
      });
    }
    return routes.length ? routes : null;
  } catch {
    return null;
  }
}

/** Straight segment between the endpoints; distance is great-circle, time ~34 km/h. */
export function straightLineRoute(coords: MapCoordinate[]): FetchRouteResult {
  const start = coords[0];
  const end = coords[coords.length - 1];
  const line: MapCoordinate[] = coords.length >= 2 ? [start, end] : coords;
  const distanceM = estimateHaversineDistance(line);
  return {
    fastest: {
      id: "straight",
      name: "Đường thẳng (chưa có định tuyến)",
      coords: line,
      distanceKm: Number((distanceM / 1000).toFixed(1)),
      durationMin: line.length >= 2 ? Math.max(1, Math.round(distanceM / 9.5 / 60)) : 0,
      summary: "Khoảng cách đường chim bay — chưa cấu hình dịch vụ định tuyến",
      isFastest: true,
    },
    alternatives: [],
  };
}

// Route between the first and last point: server routes when available, else a straight line.
export async function fetchRealRoadRoute(
  coords: MapCoordinate[],
): Promise<FetchRouteResult> {
  if (coords.length < 2) {
    return straightLineRoute(coords);
  }

  const start = coords[0];
  const end = coords[coords.length - 1];
  const key = `fastest;${start[0].toFixed(5)},${start[1].toFixed(5)};${end[0].toFixed(5)},${end[1].toFixed(5)}`;
  const cached = routeCache.get(key);
  if (cached) return cached;

  const candidates = await fetchServerRoutes(start, end);
  if (!candidates) {
    // Not cached: the provider may come back (or be configured) later.
    return straightLineRoute(coords);
  }

  candidates.sort((a, b) => a.durationSec - b.durationSec);

  const fastestOption: RoadRouteOption = {
    id: "fastest",
    name: "Lộ trình nhanh nhất (Ưu tiên)",
    coords: candidates[0].coords,
    distanceKm: Number((candidates[0].distanceM / 1000).toFixed(1)),
    durationMin: Math.max(1, Math.round(candidates[0].durationSec / 60)),
    summary: candidates[0].summary,
    isFastest: true,
  };

  const alternativeOptions: RoadRouteOption[] = candidates
    .slice(1)
    .map((c, idx) => ({
      id: `alt-${idx + 1}`,
      name: `Tuyến thay thế ${idx + 1}`,
      coords: c.coords,
      distanceKm: Number((c.distanceM / 1000).toFixed(1)),
      durationMin: Math.max(1, Math.round(c.durationSec / 60)),
      summary: c.summary,
      isFastest: false,
    }));

  const result: FetchRouteResult = {
    fastest: fastestOption,
    alternatives: alternativeOptions,
  };

  routeCache.set(key, result);
  return result;
}

export function computeFitBounds(
  coords: MapCoordinate[],
  containerWidth: number,
  containerHeight: number,
  padding = 72,
): { center: MapCoordinate; zoom: number } | null {
  if (coords.length === 0) return null;
  if (coords.length === 1) return { center: coords[0], zoom: 14.5 };

  let minLat = 90;
  let maxLat = -90;
  let minLng = 180;
  let maxLng = -180;

  for (const [lat, lng] of coords) {
    if (lat < minLat) minLat = lat;
    if (lat > maxLat) maxLat = lat;
    if (lng < minLng) minLng = lng;
    if (lng > maxLng) maxLng = lng;
  }

  const centerLat = (minLat + maxLat) / 2;
  const centerLng = (minLng + maxLng) / 2;

  const latSpan = Math.max(0.005, maxLat - minLat);
  const lngSpan = Math.max(0.005, maxLng - minLng);

  const availableWidth = Math.max(120, containerWidth - padding * 2);
  const availableHeight = Math.max(120, containerHeight - padding * 2);

  const zoomLng = Math.log2((360 * availableWidth) / (lngSpan * 256));
  const zoomLat = Math.log2((180 * availableHeight) / (latSpan * 256));
  const rawZoom = Math.min(zoomLng, zoomLat);
  const optimalZoom = Math.min(16.5, Math.max(10, Math.floor(rawZoom * 2) / 2));

  return {
    center: [centerLat, centerLng],
    zoom: optimalZoom,
  };
}

export function RealMapView({
  center = [16.0544, 108.2022],
  zoom: initialZoom = 13.5,
  minZoom = 9,
  maxZoom = 19,
  height = 460,
  markers = [],
  polygons = [],
  route = [],
  startLabel,
  endLabel,
  selectedPolygonId,
  onPolygonSelect,
  interactive = true,
  className = "",
  showControls = true,
  showAttribution = true,
  showDriverProgress = true,
  onRouteMetricsChange,
}: RealMapViewProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [zoom, setZoom] = useState(initialZoom);
  const [currentCenter, setCurrentCenter] = useState<MapCoordinate>(center);
  const [dimensions, setDimensions] = useState({ width: 640, height: 420 });
  const [isDragging, setIsDragging] = useState(false);
  const [dragStart, setDragStart] = useState({ x: 0, y: 0 });
  const [selectedMarker, setSelectedMarker] = useState<MapMarker | null>(null);
  const [tileLayer, setTileLayer] = useState<
    "auto" | "mapbox" | "osm" | "carto" | "dark"
  >("auto");
  const [isFullscreen, setIsFullscreen] = useState(false);

  // Multi-route state: Fastest route and alternative options
  const [routeOptions, setRouteOptions] = useState<RoadRouteOption[]>([]);
  const [selectedRouteIndex, setSelectedRouteIndex] = useState(0);
  const [isLoadingRoute, setIsLoadingRoute] = useState(false);

  // References for high-frequency wheel and gesture events without re-binding
  const centerRef = useRef(currentCenter);
  const zoomRef = useRef(zoom);
  const dimensionsRef = useRef(dimensions);
  const boundsRef = useRef({ minZoom, maxZoom });

  useEffect(() => {
    centerRef.current = currentCenter;
    zoomRef.current = zoom;
    dimensionsRef.current = dimensions;
    boundsRef.current = { minZoom, maxZoom };
  });

  // Theme detection
  let themeContext: ReturnType<typeof useTheme> | null = null;
  try {
    // eslint-disable-next-line react-hooks/rules-of-hooks
    themeContext = useTheme();
  } catch {
    // fallback
  }
  const isDark = themeContext ? themeContext.resolvedTheme === "dark" : false;

  const effectiveTileLayer =
    tileLayer === "auto"
      ? Boolean(MAPBOX_DEFAULT_TOKEN)
        ? "mapbox"
        : isDark
          ? "dark"
          : "osm"
      : tileLayer === "mapbox" && !MAPBOX_DEFAULT_TOKEN
        ? "osm"
        : tileLayer;

  const centerLat = center[0];
  const centerLng = center[1];

  // Synchronize center when parent passes new coordinates during render
  const [prevCenterProp, setPrevCenterProp] = useState<[number, number]>([
    centerLat,
    centerLng,
  ]);
  if (
    Math.abs(prevCenterProp[0] - centerLat) >= 0.00001 ||
    Math.abs(prevCenterProp[1] - centerLng) >= 0.00001
  ) {
    setPrevCenterProp([centerLat, centerLng]);
    setCurrentCenter([centerLat, centerLng]);
  }

  // Synchronize zoom when parent passes new initialZoom during render
  const [prevInitialZoom, setPrevInitialZoom] = useState(initialZoom);
  if (Math.abs(prevInitialZoom - initialZoom) >= 0.01) {
    setPrevInitialZoom(initialZoom);
    setZoom(initialZoom);
  }

  // Primitive stable key representing the route coordinates
  const routeKey = useMemo(() => {
    if (!route || route.length < 2) return "";
    return route.map((p) => `${p[0].toFixed(5)},${p[1].toFixed(5)}`).join(";");
  }, [route]);

  const [prevRouteKey, setPrevRouteKey] = useState(routeKey);
  if (routeKey !== prevRouteKey) {
    setPrevRouteKey(routeKey);
    setRouteOptions([]);
    setSelectedRouteIndex(0);
  }

  // Fetch optimal fastest road-network route only when route points change
  useEffect(() => {
    if (!routeKey) {
      return;
    }

    let isCancelled = false;

    fetchRealRoadRoute(route)
      .then((res) => {
        if (isCancelled) return;
        const allRoutes = [res.fastest, ...res.alternatives];
        setRouteOptions(allRoutes);
        setSelectedRouteIndex(0);

        onRouteMetricsChange?.({
          distanceKm: res.fastest.distanceKm,
          durationMin: res.fastest.durationMin,
        });
        setIsLoadingRoute(false);

        // Fit bounds to the fastest road route using current container dimensions
        const { width: curW, height: curH } = dimensionsRef.current;
        const fit = computeFitBounds(res.fastest.coords, curW, curH, 72);
        if (fit) {
          setCurrentCenter(fit.center);
          setZoom(fit.zoom);
        }
      })
      .catch(() => {
        if (isCancelled) return;
        setRouteOptions([straightLineRoute(route).fastest]);
        setSelectedRouteIndex(0);
        setIsLoadingRoute(false);
      });

    return () => {
      isCancelled = true;
    };
  }, [routeKey, route, onRouteMetricsChange]);

  // Track container dimensions with ResizeObserver
  useEffect(() => {
    if (!containerRef.current) return;
    const observer = new ResizeObserver((entries) => {
      const entry = entries[0];
      if (entry) {
        setDimensions({
          width: Math.max(280, entry.contentRect.width),
          height: Math.max(200, entry.contentRect.height),
        });
      }
    });
    observer.observe(containerRef.current);
    return () => observer.disconnect();
  }, []);

  // Listen for Escape key to exit fullscreen
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape" && isFullscreen) {
        setIsFullscreen(false);
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [isFullscreen]);

  // Core Google Maps-style focal-point zoom function
  const applyFocalZoom = useCallback(
    (zoomDelta: number, mouseX: number, mouseY: number) => {
      const curZoom = zoomRef.current;
      const curCenter = centerRef.current;
      const { width: w, height: h } = dimensionsRef.current;
      const { minZoom: minZ, maxZoom: maxZ } = boundsRef.current;

      const targetZoom = Math.max(minZ, Math.min(maxZ, curZoom + zoomDelta));
      if (Math.abs(targetZoom - curZoom) < 0.001) return;

      const cPixOld = latLngToWorldPixel(curCenter[0], curCenter[1], curZoom);
      const mPixOld = {
        x: cPixOld.x + (mouseX - w / 2),
        y: cPixOld.y + (mouseY - h / 2),
      };
      const [mLat, mLng] = worldPixelToLatLng(mPixOld.x, mPixOld.y, curZoom);

      const mPixNew = latLngToWorldPixel(mLat, mLng, targetZoom);
      const cPixNew = {
        x: mPixNew.x - (mouseX - w / 2),
        y: mPixNew.y - (mouseY - h / 2),
      };
      const [newLat, newLng] = worldPixelToLatLng(
        cPixNew.x,
        cPixNew.y,
        targetZoom,
      );

      setZoom(Number(targetZoom.toFixed(2)));
      setCurrentCenter([
        Math.max(-85, Math.min(85, newLat)),
        ((((newLng + 180) % 360) + 360) % 360) - 180,
      ]);
    },
    [],
  );

  // Smooth wheel zoom listener attached natively with { passive: false }
  useEffect(() => {
    const container = containerRef.current;
    if (!container || !interactive) return;

    let accumulatedDelta = 0;
    let animationFrameId: number | null = null;
    let lastMouseX = dimensionsRef.current.width / 2;
    let lastMouseY = dimensionsRef.current.height / 2;

    const flushZoom = () => {
      if (Math.abs(accumulatedDelta) > 0.0001) {
        const step = Math.max(-0.35, Math.min(0.35, accumulatedDelta));
        applyFocalZoom(step, lastMouseX, lastMouseY);
        accumulatedDelta = 0;
      }
      animationFrameId = null;
    };

    const handleNativeWheel = (e: WheelEvent) => {
      e.preventDefault();
      e.stopPropagation();

      const rect = container.getBoundingClientRect();
      lastMouseX = e.clientX - rect.left;
      lastMouseY = e.clientY - rect.top;

      let delta = -e.deltaY;
      if (e.deltaMode === 1) delta *= 20;
      else if (e.deltaMode === 2) delta *= 120;

      const zoomFactor = 0.0015;
      accumulatedDelta += delta * zoomFactor;

      if (!animationFrameId) {
        animationFrameId = requestAnimationFrame(flushZoom);
      }
    };

    container.addEventListener("wheel", handleNativeWheel, { passive: false });
    return () => {
      container.removeEventListener("wheel", handleNativeWheel);
      if (animationFrameId) cancelAnimationFrame(animationFrameId);
    };
  }, [interactive, applyFocalZoom]);

  // Touch gesture pinch-to-zoom support
  const touchStartDistRef = useRef<number | null>(null);
  const touchStartZoomRef = useRef<number>(zoom);

  const handleTouchStart = (e: React.TouchEvent) => {
    if (!interactive) return;
    if (e.touches.length === 2) {
      const dx = e.touches[0].clientX - e.touches[1].clientX;
      const dy = e.touches[0].clientY - e.touches[1].clientY;
      touchStartDistRef.current = Math.hypot(dx, dy);
      touchStartZoomRef.current = zoom;
    } else if (e.touches.length === 1) {
      setIsDragging(true);
      setDragStart({ x: e.touches[0].clientX, y: e.touches[0].clientY });
    }
  };

  const handleTouchMove = (e: React.TouchEvent) => {
    if (!interactive) return;
    if (e.touches.length === 2 && touchStartDistRef.current) {
      const dx = e.touches[0].clientX - e.touches[1].clientX;
      const dy = e.touches[0].clientY - e.touches[1].clientY;
      const dist = Math.hypot(dx, dy);
      const ratio = dist / touchStartDistRef.current;
      const deltaZoom = Math.log2(ratio);

      const rect = containerRef.current?.getBoundingClientRect();
      const midX = rect
        ? (e.touches[0].clientX + e.touches[1].clientX) / 2 - rect.left
        : dimensions.width / 2;
      const midY = rect
        ? (e.touches[0].clientY + e.touches[1].clientY) / 2 - rect.top
        : dimensions.height / 2;

      const targetZoom = Math.max(
        minZoom,
        Math.min(maxZoom, touchStartZoomRef.current + deltaZoom),
      );
      applyFocalZoom(targetZoom - zoomRef.current, midX, midY);
    } else if (e.touches.length === 1 && isDragging) {
      const dx = e.touches[0].clientX - dragStart.x;
      const dy = e.touches[0].clientY - dragStart.y;
      setDragStart({ x: e.touches[0].clientX, y: e.touches[0].clientY });

      const curPix = latLngToWorldPixel(
        currentCenter[0],
        currentCenter[1],
        zoom,
      );
      const nextCenter = worldPixelToLatLng(curPix.x - dx, curPix.y - dy, zoom);
      setCurrentCenter(nextCenter);
    }
  };

  const handleTouchEnd = () => {
    touchStartDistRef.current = null;
    setIsDragging(false);
  };

  // Drag pan handlers
  const handleMouseDown = (e: React.MouseEvent) => {
    if (!interactive || e.button !== 0) return;
    setIsDragging(true);
    setDragStart({ x: e.clientX, y: e.clientY });
  };

  const handleMouseMove = (e: React.MouseEvent) => {
    if (!isDragging || !interactive) return;
    const dx = e.clientX - dragStart.x;
    const dy = e.clientY - dragStart.y;
    setDragStart({ x: e.clientX, y: e.clientY });

    const curPix = latLngToWorldPixel(currentCenter[0], currentCenter[1], zoom);
    const nextCenter = worldPixelToLatLng(curPix.x - dx, curPix.y - dy, zoom);
    setCurrentCenter(nextCenter);
  };

  const handleMouseUp = () => {
    setIsDragging(false);
  };

  const handleDoubleClick = (e: React.MouseEvent) => {
    if (!interactive) return;
    const rect = containerRef.current?.getBoundingClientRect();
    if (!rect) return;
    const mouseX = e.clientX - rect.left;
    const mouseY = e.clientY - rect.top;
    applyFocalZoom(0.75, mouseX, mouseY);
  };

  const activeRoute =
    routeOptions[selectedRouteIndex] || routeOptions[0] || null;

  const handleReset = () => {
    if (activeRoute && activeRoute.coords.length >= 2) {
      const fit = computeFitBounds(
        activeRoute.coords,
        dimensions.width,
        dimensions.height,
        72,
      );
      if (fit) {
        setCurrentCenter(fit.center);
        setZoom(fit.zoom);
        setSelectedMarker(null);
        return;
      }
    }
    setCurrentCenter(center);
    setZoom(initialZoom);
    setSelectedMarker(null);
  };

  const { width, height: h } = dimensions;

  // Fractional zoom tile calculation: integer base tileZ with smooth scaling
  const tileZoom = Math.max(minZoom, Math.min(maxZoom, Math.round(zoom)));
  const scale = 2 ** (zoom - tileZoom);
  const centerPixelTileZ = latLngToWorldPixel(
    currentCenter[0],
    currentCenter[1],
    tileZoom,
  );
  const centerPixel = latLngToWorldPixel(
    currentCenter[0],
    currentCenter[1],
    zoom,
  );

  // Calculate visible tiles needed to cover container smoothly
  const tiles = useMemo(() => {
    const n = 2 ** tileZoom;
    const halfW = width / 2;
    const halfH = h / 2;

    const minX = Math.floor((centerPixelTileZ.x - halfW / scale) / 256) - 1;
    const maxX = Math.floor((centerPixelTileZ.x + halfW / scale) / 256) + 1;
    const minY = Math.floor((centerPixelTileZ.y - halfH / scale) / 256) - 1;
    const maxY = Math.floor((centerPixelTileZ.y + halfH / scale) / 256) + 1;

    const list: {
      x: number;
      y: number;
      left: number;
      top: number;
      size: number;
      key: string;
      url: string;
    }[] = [];

    const tileSize = Math.ceil(256 * scale) + 0.5;

    for (let tx = minX; tx <= maxX; tx++) {
      for (let ty = minY; ty <= maxY; ty++) {
        const wrappedX = ((tx % n) + n) % n;
        if (ty < 0 || ty >= n) continue;

        const left = halfW + (tx * 256 - centerPixelTileZ.x) * scale;
        const top = halfH + (ty * 256 - centerPixelTileZ.y) * scale;

        let url = `https://tile.openstreetmap.org/${tileZoom}/${wrappedX}/${ty}.png`;
        if (effectiveTileLayer === "mapbox" && MAPBOX_DEFAULT_TOKEN) {
          const styleId = isDark ? "dark-v11" : "streets-v12";
          url = `https://api.mapbox.com/styles/v1/mapbox/${styleId}/tiles/256/${tileZoom}/${wrappedX}/${ty}@2x?access_token=${MAPBOX_DEFAULT_TOKEN}`;
        } else if (effectiveTileLayer === "dark") {
          url = `https://basemaps.cartocdn.com/dark_all/${tileZoom}/${wrappedX}/${ty}.png`;
        } else if (effectiveTileLayer === "carto") {
          url = `https://basemaps.cartocdn.com/rastertiles/voyager/${tileZoom}/${wrappedX}/${ty}.png`;
        }

        list.push({
          x: wrappedX,
          y: ty,
          left,
          top,
          size: tileSize,
          key: `${tileZoom}-${wrappedX}-${ty}-${effectiveTileLayer}-${isDark ? "dark" : "light"}`,
          url,
        });
      }
    }
    return list;
  }, [
    centerPixelTileZ.x,
    centerPixelTileZ.y,
    effectiveTileLayer,
    h,
    isDark,
    scale,
    tileZoom,
    width,
  ]);

  // Project any GPS coord to container screen pixels at current continuous zoom
  const project = useCallback(
    (lat: number, lng: number) => {
      const p = latLngToWorldPixel(lat, lng, zoom);
      return {
        x: width / 2 + (p.x - centerPixel.x),
        y: h / 2 + (p.y - centerPixel.y),
      };
    },
    [centerPixel.x, centerPixel.y, h, width, zoom],
  );

  // Build SVG path from any coordinate array
  const buildSvgPath = useCallback(
    (coords: MapCoordinate[]) => {
      if (coords.length < 2) return "";
      return coords
        .map((coord, idx) => {
          const { x, y } = project(coord[0], coord[1]);
          return `${idx === 0 ? "M" : "L"} ${x.toFixed(1)} ${y.toFixed(1)}`;
        })
        .join(" ");
    },
    [project],
  );

  // Active route coordinates
  const activeRouteCoords = activeRoute ? activeRoute.coords : route;
  const primaryRoutePath = useMemo(
    () => buildSvgPath(activeRouteCoords),
    [activeRouteCoords, buildSvgPath],
  );

  // Alternative route paths for user selection
  const alternativeRoutes = useMemo(() => {
    return routeOptions
      .map((opt, idx) => ({
        index: idx,
        option: opt,
        path: buildSvgPath(opt.coords),
      }))
      .filter((item) => item.index !== selectedRouteIndex);
  }, [routeOptions, selectedRouteIndex, buildSvgPath]);

  // Intermediate driver position on active road route (~38% into the trip)
  const driverInTransit = useMemo(() => {
    if (!showDriverProgress || activeRouteCoords.length < 8) return null;
    const index = Math.floor(activeRouteCoords.length * 0.38);
    const coord = activeRouteCoords[index];
    const screen = project(coord[0], coord[1]);
    return {
      lat: coord[0],
      lng: coord[1],
      x: screen.x,
      y: screen.y,
    };
  }, [activeRouteCoords, project, showDriverProgress]);

  return (
    <div
      ref={containerRef}
      onMouseDown={handleMouseDown}
      onMouseMove={handleMouseMove}
      onMouseUp={handleMouseUp}
      onMouseLeave={handleMouseUp}
      onDoubleClick={handleDoubleClick}
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
      style={{
        height: isFullscreen ? "100vh" : height,
        touchAction: "none",
        overscrollBehavior: "contain",
      }}
      className={`relative isolate overflow-hidden rounded-2xl border border-border bg-[#e5e3df] select-none ${
        interactive
          ? isDragging
            ? "cursor-grabbing"
            : "cursor-grab"
          : "cursor-default"
      } ${isFullscreen ? "fixed inset-0 z-[100] rounded-none border-none shadow-2xl" : ""} ${className}`}
    >
      <style>{`
        @keyframes dealgoRouteFlow {
          from { stroke-dashoffset: 40; }
          to { stroke-dashoffset: 0; }
        }
        .animate-route-flow {
          animation: dealgoRouteFlow 1.6s linear infinite;
        }
      `}</style>

      {/* Map Tile Canvas */}
      <div className="absolute inset-0 pointer-events-none">
        {tiles.map((tile) => (
          // eslint-disable-next-line @next/next/no-img-element -- Dynamic slippery map tiles from OSM/Mapbox
          <img
            key={tile.key}
            src={tile.url}
            alt=""
            loading="lazy"
            decoding="async"
            className="absolute max-w-none transition-opacity duration-150"
            style={{
              width: `${tile.size}px`,
              height: `${tile.size}px`,
              transform: `translate3d(${tile.left}px, ${tile.top}px, 0)`,
            }}
            onError={(e) => {
              (e.currentTarget as HTMLImageElement).style.backgroundColor =
                isDark ? "#1e293b" : "#e2e8f0";
            }}
          />
        ))}
      </div>

      {/* SVG Vector Overlays: Polygons, Alternative Routes, Primary Fastest Route */}
      <svg
        className="absolute inset-0 size-full pointer-events-none"
        width={width}
        height={h}
        viewBox={`0 0 ${width} ${h}`}
      >
        <defs>
          <linearGradient
            id="route-gradient"
            x1="0%"
            y1="0%"
            x2="100%"
            y2="100%"
          >
            <stop offset="0%" stopColor="#2563eb" />
            <stop offset="45%" stopColor="#3b82f6" />
            <stop offset="85%" stopColor="#8b5cf6" />
            <stop offset="100%" stopColor="#10b981" />
          </linearGradient>
          <filter id="route-glow" x="-20%" y="-20%" width="140%" height="140%">
            <feGaussianBlur stdDeviation="3.5" result="blur" />
            <feComposite in="SourceGraphic" in2="blur" operator="over" />
          </filter>
        </defs>

        {/* Polygons (Operating Zones) */}
        {polygons.map((poly) => {
          if (poly.coords.length < 3) return null;
          const pointsStr = poly.coords
            .map((coord) => {
              const { x, y } = project(coord[0], coord[1]);
              return `${x.toFixed(1)},${y.toFixed(1)}`;
            })
            .join(" ");

          const isSelected = selectedPolygonId === poly.id || poly.active;
          const strokeColor =
            poly.color ?? (isSelected ? "#7c3aed" : "#3b82f6");
          const fillColor =
            poly.fillColor ??
            (isSelected
              ? "rgba(124, 58, 237, 0.28)"
              : "rgba(59, 130, 246, 0.12)");

          return (
            <g key={poly.id} className="pointer-events-auto cursor-pointer">
              <polygon
                points={pointsStr}
                fill={fillColor}
                stroke={strokeColor}
                strokeWidth={isSelected ? 3.5 : 2}
                strokeDasharray={isSelected ? undefined : "6 4"}
                onClick={(e) => {
                  e.stopPropagation();
                  onPolygonSelect?.(poly.id);
                }}
              />
            </g>
          );
        })}

        {/* Alternative Routes (Selectable dashed paths) */}
        {alternativeRoutes.map((alt) => (
          <g
            key={alt.option.id}
            className="pointer-events-auto cursor-pointer group"
            onClick={() => setSelectedRouteIndex(alt.index)}
          >
            {/* Expanded transparent hit target */}
            <path
              d={alt.path}
              fill="none"
              stroke="transparent"
              strokeWidth="16"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
            {/* Visual dashed alternative line */}
            <path
              d={alt.path}
              fill="none"
              stroke="#64748b"
              strokeWidth="4"
              strokeDasharray="6 6"
              strokeOpacity="0.6"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </g>
        ))}

        {/* Primary Fastest Route Polyline */}
        {primaryRoutePath && (
          <g>
            {/* Outer dark casing / shadow for street contrast */}
            <path
              d={primaryRoutePath}
              fill="none"
              stroke="#1e3a8a"
              strokeWidth="9"
              strokeOpacity="0.22"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
            {/* Main high-visibility road line */}
            <path
              d={primaryRoutePath}
              fill="none"
              stroke="url(#route-gradient)"
              strokeWidth="5"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
            {/* Animated directional traffic flow pulse */}
            <path
              d={primaryRoutePath}
              fill="none"
              stroke="#ffffff"
              strokeWidth="2"
              strokeDasharray="6 14"
              strokeOpacity="0.85"
              strokeLinecap="round"
              strokeLinejoin="round"
              className="animate-route-flow"
            />
          </g>
        )}
      </svg>

      {/* Markers / Hotspots / Pins */}
      <div className="absolute inset-0 pointer-events-none">
        {markers.map((marker) => {
          const { x, y } = project(marker.lat, marker.lng);
          if (x < -40 || x > width + 40 || y < -40 || y > h + 40) return null;

          const isSelected = selectedMarker?.id === marker.id;
          const dense = markers.length > 24;
          const isCluster = marker.id.startsWith("cluster:");

          const markerStyles: Record<
            string,
            { bg: string; text: string; icon: string }
          > = {
            driver: { bg: "bg-emerald-500", text: "text-white", icon: "car" },
            pickup: { bg: "bg-blue-600", text: "text-white", icon: "pin" },
            dropoff: { bg: "bg-rose-500", text: "text-white", icon: "check" },
            warning: { bg: "bg-amber-500", text: "text-white", icon: "alert" },
            store: { bg: "bg-orange-500", text: "text-white", icon: "store" },
            hub: { bg: "bg-indigo-600", text: "text-white", icon: "buildings" },
          };

          const style =
            markerStyles[marker.type ?? "driver"] ?? markerStyles.driver;

          return (
            <div
              key={marker.id}
              onClick={(e) => {
                e.stopPropagation();
                setSelectedMarker(isSelected ? null : marker);
              }}
              className="absolute pointer-events-auto cursor-pointer transition-transform duration-150 hover:scale-110"
              style={{
                transform: `translate3d(${x - 14}px, ${y - 14}px, 0)`,
                zIndex: isSelected ? 20 : 10,
              }}
            >
              {!dense &&
              (marker.type === "driver" || marker.type === "warning") ? (
                <span
                  className={`absolute -inset-1.5 animate-ping rounded-full opacity-60 ${
                    marker.type === "warning"
                      ? "bg-amber-400"
                      : "bg-emerald-400"
                  }`}
                />
              ) : null}
              <div
                className={`relative flex items-center justify-center rounded-full shadow-md ring-2 ring-white ${style.bg} ${style.text} ${
                  isCluster ? "size-8 text-[10px] font-bold" : "size-7"
                }`}
              >
                {isCluster ? (
                  marker.label.replace(/\D/g, "") || "•"
                ) : (
                  <span className="size-2 rounded-full bg-white" />
                )}
              </div>
              {(isSelected || (!dense && !isCluster)) && marker.label ? (
                <span className="absolute top-8 left-1/2 -translate-x-1/2 whitespace-nowrap rounded-md bg-ink/85 px-1.5 py-0.5 text-[10px] font-semibold text-white shadow-xs backdrop-blur-xs">
                  {marker.label}
                </span>
              ) : null}
            </div>
          );
        })}

        {/* Start / End Route Markers */}
        {activeRouteCoords.length >= 2 && (
          <>
            {/* Start Marker A */}
            {(() => {
              const startPos = project(
                activeRouteCoords[0][0],
                activeRouteCoords[0][1],
              );
              return (
                <div
                  className="absolute pointer-events-none transition-transform duration-75"
                  style={{
                    transform: `translate3d(${startPos.x - 15}px, ${startPos.y - 15}px, 0)`,
                    zIndex: 14,
                  }}
                >
                  <span className="absolute -inset-1 animate-ping rounded-full bg-emerald-400 opacity-60" />
                  <div className="relative flex size-8 items-center justify-center rounded-full bg-emerald-600 text-white shadow-lg ring-2 ring-white">
                    <span className="text-xs font-black">A</span>
                  </div>
                  {startLabel && (
                    <span className="absolute top-9 left-1/2 -translate-x-1/2 whitespace-nowrap rounded-md bg-emerald-700/95 px-2 py-0.5 text-[11px] font-bold text-white shadow-md backdrop-blur-xs">
                      {startLabel}
                    </span>
                  )}
                </div>
              );
            })()}

            {/* End Marker B */}
            {(() => {
              const endCoord = activeRouteCoords[activeRouteCoords.length - 1];
              const endPos = project(endCoord[0], endCoord[1]);
              return (
                <div
                  className="absolute pointer-events-none transition-transform duration-75"
                  style={{
                    transform: `translate3d(${endPos.x - 15}px, ${endPos.y - 15}px, 0)`,
                    zIndex: 14,
                  }}
                >
                  <span className="absolute -inset-1 animate-ping rounded-full bg-rose-400 opacity-60" />
                  <div className="relative flex size-8 items-center justify-center rounded-full bg-rose-600 text-white shadow-lg ring-2 ring-white">
                    <span className="text-xs font-black">B</span>
                  </div>
                  {endLabel && (
                    <span className="absolute top-9 left-1/2 -translate-x-1/2 whitespace-nowrap rounded-md bg-rose-700/95 px-2 py-0.5 text-[11px] font-bold text-white shadow-md backdrop-blur-xs">
                      {endLabel}
                    </span>
                  )}
                </div>
              );
            })()}

            {/* Live Driver In-Transit Indicator on Route */}
            {driverInTransit && (
              <div
                className="absolute pointer-events-none transition-all duration-300"
                style={{
                  transform: `translate3d(${driverInTransit.x - 16}px, ${driverInTransit.y - 16}px, 0)`,
                  zIndex: 16,
                }}
              >
                <span className="absolute -inset-1.5 animate-ping rounded-full bg-brand opacity-70" />
                <div className="relative flex size-8 items-center justify-center rounded-full bg-brand text-white shadow-xl ring-2 ring-white">
                  <OpsIcon name="car" className="size-4" />
                </div>
                <span className="absolute top-9 left-1/2 -translate-x-1/2 whitespace-nowrap rounded-md bg-brand/95 px-2 py-0.5 text-[10px] font-bold text-white shadow-md backdrop-blur-xs">
                  Tài xế đang chạy · 38 km/h
                </span>
              </div>
            )}
          </>
        )}
      </div>

      {/* Selected Marker Popup Card */}
      {selectedMarker && (
        <div
          className="absolute z-20 rounded-xl border border-border bg-white p-3 shadow-xl pointer-events-auto max-w-xs animate-in fade-in zoom-in-95 duration-150"
          style={{
            left: Math.min(
              width - 240,
              Math.max(
                16,
                project(selectedMarker.lat, selectedMarker.lng).x - 100,
              ),
            ),
            top: Math.max(
              16,
              project(selectedMarker.lat, selectedMarker.lng).y - 110,
            ),
          }}
        >
          <div className="flex items-start justify-between gap-2">
            <div>
              <p className="text-xs font-bold text-ink">
                {selectedMarker.label}
              </p>
              {selectedMarker.status && (
                <span className="inline-block rounded-md bg-emerald-50 px-1.5 py-0.5 text-[10px] font-medium text-emerald-700">
                  {selectedMarker.status}
                </span>
              )}
            </div>
            <button
              type="button"
              onClick={() => setSelectedMarker(null)}
              className="rounded-md p-1 text-muted hover:text-ink hover:bg-canvas cursor-pointer"
            >
              ✕
            </button>
          </div>
          {selectedMarker.detail && (
            <p className="mt-1 text-xs text-muted leading-4">
              {selectedMarker.detail}
            </p>
          )}
          <p className="mt-1 text-[10px] font-mono text-muted/70">
            {selectedMarker.lat.toFixed(4)}, {selectedMarker.lng.toFixed(4)}
          </p>
        </div>
      )}

      {/* Floating Map Controls Toolbar */}
      {showControls && (
        <div className="absolute top-3 right-3 z-10 flex flex-col items-center gap-1.5 pointer-events-auto">
          {/* Zoom In */}
          <button
            type="button"
            title="Phóng to (+)"
            onClick={() => applyFocalZoom(0.75, width / 2, h / 2)}
            disabled={zoom >= maxZoom}
            className="flex size-8 items-center justify-center rounded-lg border border-border bg-white/95 text-ink shadow-sm hover:bg-white disabled:opacity-40 cursor-pointer backdrop-blur-xs transition-colors"
          >
            <span className="text-base font-bold">+</span>
          </button>
          {/* Zoom Out */}
          <button
            type="button"
            title="Thu nhỏ (−)"
            onClick={() => applyFocalZoom(-0.75, width / 2, h / 2)}
            disabled={zoom <= minZoom}
            className="flex size-8 items-center justify-center rounded-lg border border-border bg-white/95 text-ink shadow-sm hover:bg-white disabled:opacity-40 cursor-pointer backdrop-blur-xs transition-colors"
          >
            <span className="text-base font-bold">−</span>
          </button>
          {/* Center Reset */}
          <button
            type="button"
            title="Về trung tâm lộ trình"
            onClick={handleReset}
            className="flex size-8 items-center justify-center rounded-lg border border-border bg-white/95 text-ink shadow-sm hover:bg-white cursor-pointer backdrop-blur-xs transition-colors"
          >
            <OpsIcon name="pin" className="size-4 text-brand" />
          </button>
          {/* Toggle Map Layer */}
          <button
            type="button"
            title={`Chế độ bản đồ: ${
              tileLayer === "auto"
                ? `Tự động (${effectiveTileLayer.toUpperCase()})`
                : tileLayer.toUpperCase()
            }`}
            onClick={() =>
              setTileLayer((prev) =>
                prev === "auto"
                  ? MAPBOX_DEFAULT_TOKEN
                    ? "mapbox"
                    : "osm"
                  : prev === "mapbox"
                    ? "osm"
                    : prev === "osm"
                      ? "carto"
                      : prev === "carto"
                        ? "dark"
                        : "auto",
              )
            }
            className="flex size-8 items-center justify-center rounded-lg border border-border bg-white/95 text-ink shadow-sm hover:bg-white cursor-pointer backdrop-blur-xs transition-colors"
          >
            <OpsIcon name="monitor" className="size-4 text-ink" />
          </button>
          {/* Fullscreen */}
          <button
            type="button"
            title={isFullscreen ? "Thu nhỏ (Esc)" : "Toàn màn hình"}
            onClick={() => setIsFullscreen((prev) => !prev)}
            className="flex size-8 items-center justify-center rounded-lg border border-border bg-white/95 text-ink shadow-sm hover:bg-white cursor-pointer backdrop-blur-xs transition-colors"
          >
            <OpsIcon
              name={isFullscreen ? "close" : "overview"}
              className="size-4 text-ink"
            />
          </button>
        </div>
      )}

      {/* City & Live Status Badge with Route Optimization Algorithm Selector */}
      <div className="absolute top-3 left-3 z-10 flex flex-wrap items-center gap-2 pointer-events-auto">
        <div className="flex items-center gap-2 rounded-xl border border-border/80 bg-white/95 px-3 py-1.5 shadow-sm backdrop-blur-xs">
          <span className="size-2 rounded-full bg-emerald-500 animate-pulse" />
          <span className="text-xs font-bold text-ink">Đà Nẵng</span>
          <span className="text-[10px] text-muted">
            | Zoom {zoom.toFixed(1)} · {effectiveTileLayer.toUpperCase()}
          </span>
          {isLoadingRoute && (
            <span className="text-[10px] font-medium text-brand animate-pulse">
              · Đang tối ưu thuật toán lộ trình...
            </span>
          )}
        </div>

        {/* Algorithm Route Selector Pills */}
        {routeOptions.map((opt, idx) => {
          const isSelected = selectedRouteIndex === idx;
          return (
            <button
              key={opt.id}
              type="button"
              onClick={() => setSelectedRouteIndex(idx)}
              className={`flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-xs font-semibold shadow-xs cursor-pointer backdrop-blur-xs transition-all ${
                isSelected
                  ? opt.isFastest
                    ? "border border-emerald-500/30 bg-emerald-600 text-white shadow-md ring-1 ring-white/30"
                    : "border border-brand/30 bg-brand text-white shadow-md ring-1 ring-white/30"
                  : "border border-border/80 bg-white/95 text-ink hover:bg-white"
              }`}
            >
              {opt.isFastest ? (
                <span className="flex items-center gap-1">
                  <span>⚡ Nhanh nhất</span>
                </span>
              ) : (
                <span>Tuyến {idx + 1}</span>
              )}
              <span className="opacity-70">·</span>
              <span>{opt.distanceKm} km</span>
              <span className="opacity-70">·</span>
              <span>~{opt.durationMin}p</span>
            </button>
          );
        })}
      </div>

      {/* Attribution & Guidance */}
      {showAttribution && (
        <div className="absolute bottom-1 right-2 z-10 pointer-events-none flex items-center gap-2">
          <span className="hidden sm:inline-block rounded bg-white/80 px-1.5 py-0.5 text-[9px] text-muted shadow-2xs backdrop-blur-xs">
            Cuộn chuột để zoom mượt · Giữ & kéo để di chuyển · Định tuyến qua
            máy chủ DealGo
          </span>
          <span className="rounded bg-white/80 px-1.5 py-0.5 text-[9px] text-muted shadow-2xs backdrop-blur-xs">
            {effectiveTileLayer === "mapbox" ? (
              <>
                ©{" "}
                <a
                  href="https://www.mapbox.com/about/maps/"
                  target="_blank"
                  rel="noreferrer"
                  className="underline pointer-events-auto"
                >
                  Mapbox
                </a>{" "}
                · ©{" "}
                <a
                  href="https://www.openstreetmap.org/copyright"
                  target="_blank"
                  rel="noreferrer"
                  className="underline pointer-events-auto"
                >
                  OpenStreetMap
                </a>
              </>
            ) : (
              <>
                ©{" "}
                <a
                  href="https://www.openstreetmap.org/copyright"
                  target="_blank"
                  rel="noreferrer"
                  className="underline pointer-events-auto"
                >
                  OpenStreetMap
                </a>{" "}
                contributors
              </>
            )}
          </span>
        </div>
      )}
    </div>
  );
}
