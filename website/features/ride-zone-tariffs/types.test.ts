import { describe, expect, it } from "vitest";
import { validateZoneTariff } from "./types";

describe("validateZoneTariff", () => {
  it("accepts in-range integers", () => {
    expect(validateZoneTariff({ perKmVnd: 5000, minFareVnd: 10000 }, 500000)).toBeNull();
  });
  it("rejects out-of-range per-km and min fare above class max", () => {
    expect(validateZoneTariff({ perKmVnd: 100001, minFareVnd: 0 }, 500000)).not.toBeNull();
    expect(validateZoneTariff({ perKmVnd: 1.5, minFareVnd: 0 }, 500000)).not.toBeNull();
    expect(validateZoneTariff({ perKmVnd: 5000, minFareVnd: 600000 }, 500000)).not.toBeNull();
  });
});
