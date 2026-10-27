import { describe, expect, it } from "vitest";
import {
  checkHomeBannerImageBody,
  checkHomeBannerReorderBody,
  pickHomeBannerBody,
} from "./ops-home-banner-body";

const A = "11111111-1111-4111-8111-111111111111";
const B = "22222222-2222-4222-8222-222222222222";

describe("pickHomeBannerBody", () => {
  it("drops unknown keys and keeps explicit nulls", () => {
    expect(
      pickHomeBannerBody({
        title: "X",
        ctaUrl: "/customer/shop",
        regionCode: null,
        imageUrl: "/x",
        id: A,
      }),
    ).toEqual({ ok: true, value: { ctaUrl: "/customer/shop", regionCode: null } });
  });

  it("rejects non-objects and empty patches", () => {
    expect(pickHomeBannerBody([]).ok).toBe(false);
    expect(pickHomeBannerBody({ imageUrl: "/x" }).ok).toBe(false);
  });
});

describe("checkHomeBannerReorderBody", () => {
  it("accepts unique uuids only", () => {
    expect(checkHomeBannerReorderBody({ ids: [A, B] })).toEqual({
      ok: true,
      value: { ids: [A, B] },
    });
    expect(checkHomeBannerReorderBody({ ids: [A, A] }).ok).toBe(false);
    expect(checkHomeBannerReorderBody({ ids: ["x"] }).ok).toBe(false);
    expect(checkHomeBannerReorderBody({ ids: [] }).ok).toBe(false);
  });
});

describe("checkHomeBannerImageBody", () => {
  it("accepts base64 jpeg/png/webp data urls under the limit", () => {
    expect(
      checkHomeBannerImageBody({ dataUrl: "data:image/png;base64,AAAA" }).ok,
    ).toBe(true);
    expect(
      checkHomeBannerImageBody({ dataUrl: "data:image/svg+xml;base64,AA" }).ok,
    ).toBe(false);
    expect(
      checkHomeBannerImageBody({
        dataUrl: `data:image/png;base64,${"A".repeat(2_700_001)}`,
      }).ok,
    ).toBe(false);
  });
});
