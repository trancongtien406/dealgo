import { describe, expect, it } from "vitest";
import {
  applyBoxDrag,
  boxFromCorners,
  recenterBox,
  type GeoBox,
} from "@/components/ui/map-box-edit";

const box: GeoBox = { minLat: 16, maxLat: 16.2, minLng: 108, maxLng: 108.3 };

describe("map box edit geometry", () => {
  it("normalises corners in any order", () => {
    expect(boxFromCorners([16.2, 108.3], [16, 108])).toEqual(box);
  });

  it("moves the whole box by the drag delta", () => {
    expect(applyBoxDrag(box, "move", [16.1, 108.1], [16.15, 108.2])).toEqual({
      minLat: 16.05,
      maxLat: 16.25,
      minLng: 108.1,
      maxLng: 108.4,
    });
  });

  it("resizes from a corner and keeps the opposite corner fixed", () => {
    expect(applyBoxDrag(box, "ne", [16.2, 108.3], [16.3, 108.5])).toEqual({
      minLat: 16,
      maxLat: 16.3,
      minLng: 108,
      maxLng: 108.5,
    });
    expect(applyBoxDrag(box, "sw", [16, 108], [15.9, 107.9])).toEqual({
      minLat: 15.9,
      maxLat: 16.2,
      minLng: 107.9,
      maxLng: 108.3,
    });
  });

  it("flips instead of inverting when a corner crosses the far edge", () => {
    const out = applyBoxDrag(box, "nw", [16.2, 108], [15.9, 108.4]);
    expect(out.minLat).toBeLessThan(out.maxLat);
    expect(out.minLng).toBeLessThan(out.maxLng);
    expect(out).toEqual({ minLat: 15.9, maxLat: 16, minLng: 108.3, maxLng: 108.4 });
  });

  it("draws a fresh box from the press point", () => {
    expect(applyBoxDrag(box, "draw", [10.9, 106.8], [10.7, 106.6])).toEqual({
      minLat: 10.7,
      maxLat: 10.9,
      minLng: 106.6,
      maxLng: 106.8,
    });
  });

  it("recentres keeping the size", () => {
    expect(recenterBox(box, [10.8, 106.7])).toEqual({
      minLat: 10.7,
      maxLat: 10.9,
      minLng: 106.55,
      maxLng: 106.85,
    });
  });
});
