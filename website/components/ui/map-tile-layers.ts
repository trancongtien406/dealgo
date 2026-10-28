/**
 * Admin map base layers. Every styled layer is a Mapbox style served with the
 * Mapbox public token (Admin, else `NEXT_PUBLIC_MAPBOX_TOKEN`); without one the map uses keyless OpenStreetMap
 * tiles. CARTO basemaps are not used: they now return "API KEY REQUIRED" tiles.
 */
export type TileLayerChoice = "auto" | "streets" | "satellite" | "dark" | "osm";

export type ResolvedTileLayer =
  | { kind: "mapbox"; styleId: "streets-v12" | "dark-v11" | "satellite-streets-v12"; label: string }
  | { kind: "osm"; label: string };

export const TILE_LAYER_LABELS: Record<TileLayerChoice, string> = {
  auto: "Tự động",
  streets: "Đường phố",
  satellite: "Vệ tinh",
  dark: "Tối",
  osm: "OpenStreetMap",
};

export const MAP_STYLE_STORAGE_KEY = "dealgo.admin.mapStyle";

/** Layers the style button cycles through. No token → only the OSM fallback. */
export function availableTileLayers(hasToken: boolean): TileLayerChoice[] {
  return hasToken ? ["auto", "streets", "satellite", "dark", "osm"] : ["auto"];
}

export function nextTileLayer(current: TileLayerChoice, hasToken: boolean): TileLayerChoice {
  const list = availableTileLayers(hasToken);
  const i = list.indexOf(current);
  return list[(i + 1) % list.length] ?? "auto";
}

/** Unknown / stored values that this build cannot draw fall back to `auto`. */
export function sanitizeTileLayer(value: unknown, hasToken: boolean): TileLayerChoice {
  return typeof value === "string" &&
    (availableTileLayers(hasToken) as string[]).includes(value)
    ? (value as TileLayerChoice)
    : "auto";
}

export function resolveTileLayer(
  choice: TileLayerChoice,
  hasToken: boolean,
  isDark: boolean,
): ResolvedTileLayer {
  if (!hasToken || choice === "osm") {
    return { kind: "osm", label: "OSM" };
  }
  switch (choice) {
    case "satellite":
      return { kind: "mapbox", styleId: "satellite-streets-v12", label: "VỆ TINH" };
    case "dark":
      return { kind: "mapbox", styleId: "dark-v11", label: "TỐI" };
    case "streets":
      return { kind: "mapbox", styleId: "streets-v12", label: "MAPBOX" };
    default:
      return isDark
        ? { kind: "mapbox", styleId: "dark-v11", label: "MAPBOX" }
        : { kind: "mapbox", styleId: "streets-v12", label: "MAPBOX" };
  }
}

export function tileUrl(
  layer: ResolvedTileLayer,
  z: number,
  x: number,
  y: number,
  token: string,
): string {
  if (layer.kind === "mapbox" && token) {
    return `https://api.mapbox.com/styles/v1/mapbox/${layer.styleId}/tiles/256/${z}/${x}/${y}@2x?access_token=${encodeURIComponent(token)}`;
  }
  return `https://tile.openstreetmap.org/${z}/${x}/${y}.png`;
}
