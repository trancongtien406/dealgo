import { describe, expect, it } from "vitest";
import type { ZoneItem } from "@/features/zones/types";
import {
  VN_PROVINCES,
  ZONE_CODE_PATTERN,
  defaultZoneBbox,
  fitZoneBox,
  foldVietnamese,
  matchProvinces,
  normalizeZoneCodeInput,
  overlappingZones,
  suggestZoneCode,
  zoneBboxProblem,
  zoneCodeProblem,
} from "@/features/zones/zone-form";

const zone = (code: string, bbox: ZoneItem["bbox"]): ZoneItem => ({
  code,
  name: code,
  label: code,
  status: "ACTIVE",
  bbox,
  demandRideCount: 0,
  demandFoodCount: 0,
  demandCount: 0,
});

describe("zone form helpers", () => {
  it("lists 34 provinces with unique, valid preferred codes", () => {
    expect(VN_PROVINCES).toHaveLength(34);
    const codes = VN_PROVINCES.map((p) => p.code);
    expect(new Set(codes).size).toBe(34);
    for (const c of codes) expect(c).toMatch(ZONE_CODE_PATTERN);
  });

  it("folds Vietnamese diacritics including đ", () => {
    expect(foldVietnamese("Đà Nẵng – Hội An")).toBe("Da Nang – Hoi An");
    expect(normalizeZoneCodeInput("đn-1 xyzabc")).toBe("DN1XYZAB");
  });

  it("suggests initials, skipping prefixes and taken codes", () => {
    expect(suggestZoneCode("TP. Hồ Chí Minh", [])).toBe("HCM");
    expect(suggestZoneCode("Đà Nẵng", ["dn"])).toBe("DNA");
    expect(suggestZoneCode("Đà Nẵng", ["DN", "DNA"])).toBe("DNAN");
    expect(suggestZoneCode("Huế", [])).toBe("HU");
    expect(suggestZoneCode("Huế", [], "HUE")).toBe("HUE");
    expect(suggestZoneCode("Quảng Ngãi", ["QNG"], "QNG")).toBe("QN");
  });

  it("falls back to numbered codes when everything is taken", () => {
    const taken = ["AB", "ABC"];
    expect(suggestZoneCode("A B", ["AB"])).toBe("AB2");
    expect(suggestZoneCode("Ab", taken)).toBe("AB2");
  });

  it("explains code problems", () => {
    expect(zoneCodeProblem("", [])).toMatch(/Nhập mã/);
    expect(zoneCodeProblem("1A", [])).toMatch(/2–8/);
    expect(zoneCodeProblem("DN", ["dn"])).toMatch(/đã có/);
    expect(zoneCodeProblem("DN", ["HCM"])).toBeNull();
  });

  it("builds a default box and mirrors backend bbox checks", () => {
    const b = defaultZoneBbox(16.0544, 108.2022);
    expect(b).toEqual({ minLat: 15.9044, maxLat: 16.2044, minLng: 108.0522, maxLng: 108.3522 });
    expect(zoneBboxProblem({ lat: 16.0544, lng: 108.2022 }, b)).toBeNull();
    expect(zoneBboxProblem({ lat: 17, lng: 108.2 }, b)).toMatch(/Tâm/);
    expect(
      zoneBboxProblem({ lat: 16, lng: 108 }, { minLat: 14, maxLat: 18, minLng: 107, maxLng: 109 }),
    ).toMatch(/quá lớn/);
    expect(
      zoneBboxProblem({ lat: 16, lng: 108 }, { minLat: 16, maxLat: 16, minLng: 107, maxLng: 109 }),
    ).toMatch(/diện tích/);
  });

  it("finds overlapping zones except the one being edited", () => {
    const zones = [
      zone("DN", { minLat: 15.95, maxLat: 16.22, minLng: 108.05, maxLng: 108.35 }),
      zone("HUE", { minLat: 16.35, maxLat: 16.55, minLng: 107.45, maxLng: 107.7 }),
      zone("X", undefined),
    ];
    const b = defaultZoneBbox(16.1, 108.1);
    expect(overlappingZones(b, zones).map((z) => z.code)).toEqual(["DN"]);
    expect(overlappingZones(b, zones, "DN")).toEqual([]);
  });

  it("matches provinces without diacritics", () => {
    expect(matchProvinces("da nang").map((p) => p.code)).toEqual(["DN"]);
    expect(matchProvinces("ho chi")[0]?.code).toBe("HCM");
    expect(matchProvinces("")).toHaveLength(8);
  });

  it("fits big and small boxes", () => {
    const small = fitZoneBox(defaultZoneBbox(16, 108), 600, 360);
    expect(small.center).toEqual([16, 108]);
    expect(small.zoom).toBeGreaterThanOrEqual(9);
    const big = fitZoneBox({ minLat: 9, maxLat: 12, minLng: 105, maxLng: 108 }, 600, 360);
    expect(big.zoom).toBeLessThan(small.zoom);
    expect(big.zoom).toBeGreaterThanOrEqual(5);
  });
});
