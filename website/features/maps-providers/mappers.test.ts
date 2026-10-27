import { describe, expect, it } from "vitest";
import {
  canChooseProvider,
  mapMapsProviders,
} from "@/features/maps-providers/mappers";
import type { NestMapsProviders } from "@/features/maps-providers/types";

const raw: NestMapsProviders = {
  googleConfigured: false,
  primary: { maps: "mapbox", routing: "mapbox" },
  tiles: "mapbox",
  capabilities: [
    { capability: "search", key: "MAPS_SEARCH_PROVIDER", chosen: "google", effective: "mapbox", updatedAt: "2026-10-27T01:00:00.000Z", updatedByUserId: "u1" },
    { capability: "reverse", key: "MAPS_REVERSE_PROVIDER", chosen: "mapbox", effective: "mapbox", updatedAt: null, updatedByUserId: null },
    { capability: "route", key: "MAPS_ROUTE_PROVIDER", chosen: "mapbox", effective: "mapbox", updatedAt: null, updatedByUserId: null },
  ],
};

describe("maps providers", () => {
  it("labels capabilities and flags a Google choice without a key", () => {
    const view = mapMapsProviders(raw);
    expect(view.rows.map((r) => [r.label, r.degraded])).toEqual([
      ["Tìm địa chỉ", true],
      ["Địa chỉ từ vị trí", false],
      ["Lộ trình & quãng đường", false],
    ]);
    expect(view.rows[1]!.updatedAtLabel).toBe("mặc định");
  });

  it("only offers Google when the server has a key", () => {
    expect(canChooseProvider({ googleConfigured: false }, "google")).toBe(false);
    expect(canChooseProvider({ googleConfigured: false }, "mapbox")).toBe(true);
    expect(canChooseProvider({ googleConfigured: true }, "google")).toBe(true);
  });
});
