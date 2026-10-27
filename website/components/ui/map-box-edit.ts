/**
 * Pure geometry for editing a lat/lng bounding box on RealMapView
 * (Admin › Khu vực form). No React, so it is unit-tested directly.
 */
export type GeoBox = {
  minLat: number;
  maxLat: number;
  minLng: number;
  maxLng: number;
};

export type BoxHandle = "move" | "nw" | "ne" | "sw" | "se" | "draw";

const round = (n: number, dp = 4) => {
  const f = 10 ** dp;
  return Math.round(n * f) / f;
};

export function roundBox(box: GeoBox, dp = 4): GeoBox {
  return {
    minLat: round(box.minLat, dp),
    maxLat: round(box.maxLat, dp),
    minLng: round(box.minLng, dp),
    maxLng: round(box.maxLng, dp),
  };
}

/** Box spanned by two corner points ([lat, lng]) in any order. */
export function boxFromCorners(
  a: [number, number],
  b: [number, number],
): GeoBox {
  return {
    minLat: Math.min(a[0], b[0]),
    maxLat: Math.max(a[0], b[0]),
    minLng: Math.min(a[1], b[1]),
    maxLng: Math.max(a[1], b[1]),
  };
}

/**
 * New box after dragging `handle` from `from` to `to` (both [lat, lng]),
 * starting from `start`. Corners move freely and the result is normalised,
 * so dragging a corner past the opposite edge flips instead of inverting.
 */
export function applyBoxDrag(
  start: GeoBox,
  handle: BoxHandle,
  from: [number, number],
  to: [number, number],
): GeoBox {
  const dLat = to[0] - from[0];
  const dLng = to[1] - from[1];
  switch (handle) {
    case "move":
      return roundBox({
        minLat: start.minLat + dLat,
        maxLat: start.maxLat + dLat,
        minLng: start.minLng + dLng,
        maxLng: start.maxLng + dLng,
      });
    case "draw":
      return roundBox(boxFromCorners(from, to));
    case "nw":
      return roundBox(boxFromCorners(to, [start.minLat, start.maxLng]));
    case "ne":
      return roundBox(boxFromCorners(to, [start.minLat, start.minLng]));
    case "sw":
      return roundBox(boxFromCorners(to, [start.maxLat, start.maxLng]));
    case "se":
      return roundBox(boxFromCorners(to, [start.maxLat, start.minLng]));
  }
}

/** Same box, re-centred on `center` ([lat, lng]) keeping its size. */
export function recenterBox(box: GeoBox, center: [number, number]): GeoBox {
  const halfLat = (box.maxLat - box.minLat) / 2;
  const halfLng = (box.maxLng - box.minLng) / 2;
  return roundBox({
    minLat: center[0] - halfLat,
    maxLat: center[0] + halfLat,
    minLng: center[1] - halfLng,
    maxLng: center[1] + halfLng,
  });
}
