import { describe, expect, it } from "vitest";
import {
  availableTileLayers,
  nextTileLayer,
  resolveTileLayer,
  sanitizeTileLayer,
  tileUrl,
  type TileLayerChoice,
} from "./map-tile-layers";

const TOKEN = "pk.test-token";
const ALL: TileLayerChoice[] = ["auto", "streets", "satellite", "dark", "osm"];

describe("map tile layers", () => {
  it("cycles all Mapbox styles plus OSM when a token exists", () => {
    let cur: TileLayerChoice = "auto";
    const seen: TileLayerChoice[] = [cur];
    for (let i = 0; i < 5; i += 1) {
      cur = nextTileLayer(cur, true);
      seen.push(cur);
    }
    expect(seen).toEqual(["auto", "streets", "satellite", "dark", "osm", "auto"]);
  });

  it("without a token only the keyless OSM fallback is reachable", () => {
    expect(availableTileLayers(false)).toEqual(["auto"]);
    expect(nextTileLayer("auto", false)).toBe("auto");
    for (const choice of ALL) {
      for (const dark of [false, true]) {
        expect(resolveTileLayer(choice, false, dark)).toEqual({ kind: "osm", label: "OSM" });
      }
    }
  });

  it("auto follows the theme with Mapbox styles", () => {
    expect(resolveTileLayer("auto", true, false)).toMatchObject({ kind: "mapbox", styleId: "streets-v12" });
    expect(resolveTileLayer("auto", true, true)).toMatchObject({ kind: "mapbox", styleId: "dark-v11" });
    expect(resolveTileLayer("satellite", true, true)).toMatchObject({ styleId: "satellite-streets-v12" });
    expect(resolveTileLayer("dark", true, false)).toMatchObject({ styleId: "dark-v11" });
    expect(resolveTileLayer("streets", true, true)).toMatchObject({ styleId: "streets-v12" });
    expect(resolveTileLayer("osm", true, false)).toMatchObject({ kind: "osm" });
  });

  it("never produces a CARTO (key-required) tile URL", () => {
    for (const choice of ALL) {
      for (const hasToken of [false, true]) {
        for (const dark of [false, true]) {
          const url = tileUrl(resolveTileLayer(choice, hasToken, dark), 12, 3245, 1890, hasToken ? TOKEN : "");
          expect(url).not.toMatch(/cartocdn|carto\.com/);
          expect(url.startsWith("https://")).toBe(true);
        }
      }
    }
  });

  it("builds Mapbox and OSM URLs, falling back to OSM if the token is empty", () => {
    expect(tileUrl(resolveTileLayer("satellite", true, false), 12, 1, 2, TOKEN)).toBe(
      "https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/256/12/1/2@2x?access_token=pk.test-token",
    );
    expect(tileUrl({ kind: "mapbox", styleId: "dark-v11", label: "TỐI" }, 12, 1, 2, "")).toBe(
      "https://tile.openstreetmap.org/12/1/2.png",
    );
  });

  it("sanitizes stored choices, including legacy carto/dark-carto values", () => {
    expect(sanitizeTileLayer("satellite", true)).toBe("satellite");
    expect(sanitizeTileLayer("satellite", false)).toBe("auto");
    expect(sanitizeTileLayer("carto", true)).toBe("auto");
    expect(sanitizeTileLayer("mapbox", true)).toBe("auto");
    expect(sanitizeTileLayer(null, true)).toBe("auto");
  });
});
