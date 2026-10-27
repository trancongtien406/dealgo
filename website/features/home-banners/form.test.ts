import { describe, expect, it } from "vitest";
import {
  checkHomeBannerDraft,
  diffHomeBannerPayload,
  draftFromHomeBanner,
  emptyHomeBannerDraft,
  formatCtr,
  formatIct,
  homeBannerCtaProblem,
  homeBannerImageSizeProblem,
  homeBannerImageSrc,
  ictInputToIso,
  isoToIctInput,
  moveHomeBannerId,
} from "@/features/home-banners/form";
import type { HomeBannerRow } from "@/features/home-banners/types";

const row: HomeBannerRow = {
  id: "11111111-1111-4111-8111-111111111111",
  imageUrl:
    "/v1/public/home-banners/images/11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222.png",
  ctaUrl: "/customer/book",
  audiences: ["CUSTOMER"],
  service: "RIDE",
  regionCode: "DN",
  startsAt: "2026-11-01T01:00:00.000Z",
  endsAt: null,
  sortOrder: 10,
  active: true,
  state: "LIVE",
  stats: {
    impressions: 200,
    clicks: 9,
    ctr: 0.045,
    last7d: { impressions: 50, clicks: 2 },
  },
  createdAt: "2026-10-01T00:00:00.000Z",
  updatedAt: "2026-10-01T00:00:00.000Z",
};

describe("homeBannerCtaProblem", () => {
  it("accepts allowlisted app paths, dealgo:// and https", () => {
    expect(homeBannerCtaProblem("", ["CUSTOMER"])).toBeNull();
    expect(homeBannerCtaProblem("/customer/book", ["CUSTOMER"])).toBeNull();
    expect(
      homeBannerCtaProblem("dealgo://customer/shop", ["CUSTOMER"]),
    ).toBeNull();
    expect(
      homeBannerCtaProblem("dealgo://app/driver/jobs", ["DRIVER"]),
    ).toBeNull();
    expect(
      homeBannerCtaProblem("/customer/food/stores/abc-1", ["CUSTOMER"]),
    ).toBeNull();
    expect(
      homeBannerCtaProblem("https://dealgo.vn/khuyen-mai", ["DRIVER"]),
    ).toBeNull();
  });

  it("rejects paths another audience cannot open, odd queries and bad links", () => {
    expect(
      homeBannerCtaProblem("/customer/shop", ["CUSTOMER", "DRIVER"]),
    ).toContain("Tài xế");
    expect(homeBannerCtaProblem("/customer/book?x=<", ["CUSTOMER"])).toContain(
      "truy vấn",
    );
    expect(
      homeBannerCtaProblem("http://dealgo.vn", ["CUSTOMER"]),
    ).not.toBeNull();
    expect(
      homeBannerCtaProblem("https://user:pw@dealgo.vn", ["CUSTOMER"]),
    ).not.toBeNull();
    expect(
      homeBannerCtaProblem("javascript:alert(1)", ["CUSTOMER"]),
    ).not.toBeNull();
  });
});

describe("ICT date helpers", () => {
  it("round-trips datetime-local values in UTC+7", () => {
    expect(isoToIctInput("2026-11-01T01:00:00.000Z")).toBe("2026-11-01T08:00");
    expect(ictInputToIso("2026-11-01T08:00")).toBe("2026-11-01T01:00:00.000Z");
    expect(ictInputToIso("")).toBeNull();
    expect(formatIct("2026-11-01T01:00:00.000Z")).toBe("01/11/2026 08:00 ICT");
    expect(formatIct(null)).toBe("—");
  });
});

describe("checkHomeBannerDraft", () => {
  it("builds a trimmed payload", () => {
    const result = checkHomeBannerDraft({
      ...emptyHomeBannerDraft(),
      ctaUrl: " /customer/shop ",
      startsAt: "2026-11-01T08:00",
    });
    expect(result).toEqual({
      ok: true,
      payload: {
        ctaUrl: "/customer/shop",
        audiences: ["CUSTOMER"],
        service: "ALL",
        regionCode: null,
        startsAt: "2026-11-01T01:00:00.000Z",
        endsAt: null,
      },
    });
  });

  it("needs no text and rejects no audience or an end before the start", () => {
    expect(checkHomeBannerDraft(emptyHomeBannerDraft()).ok).toBe(true);
    expect(
      checkHomeBannerDraft({
        ...emptyHomeBannerDraft(),
        audiences: [],
      }).ok,
    ).toBe(false);
    expect(
      checkHomeBannerDraft({
        ...emptyHomeBannerDraft(),
        startsAt: "2026-11-02T08:00",
        endsAt: "2026-11-01T08:00",
      }).ok,
    ).toBe(false);
  });
});

describe("diffHomeBannerPayload", () => {
  it("is empty for an unchanged draft and lists only edits", () => {
    const check = checkHomeBannerDraft(draftFromHomeBanner(row));
    if (!check.ok) throw new Error(check.message);
    expect(diffHomeBannerPayload(row, check.payload)).toEqual({});
    expect(
      diffHomeBannerPayload(row, {
        ...check.payload,
        regionCode: null,
        ctaUrl: null,
      }),
    ).toEqual({ regionCode: null, ctaUrl: null });
  });
});

describe("homeBannerImageSizeProblem", () => {
  it("accepts ~2:1 art of a usable width", () => {
    expect(homeBannerImageSizeProblem(1200, 600)).toBeNull();
    expect(homeBannerImageSizeProblem(1080, 560)).toBeNull();
  });

  it("warns about wrong ratios, tiny images and unreadable sizes", () => {
    expect(homeBannerImageSizeProblem(1080, 1080)).toMatch(/2:1/);
    expect(homeBannerImageSizeProblem(600, 300)).toMatch(/nhỏ/);
    expect(homeBannerImageSizeProblem(0, 0)).toMatch(/kích thước/);
  });
});

describe("misc", () => {
  it("moves ids within bounds", () => {
    expect(moveHomeBannerId(["a", "b", "c"], "b", -1)).toEqual(["b", "a", "c"]);
    expect(moveHomeBannerId(["a", "b", "c"], "c", 1)).toBeNull();
  });

  it("formats ctr and maps preview images to the same-origin proxy", () => {
    expect(formatCtr(0.045)).toBe("4.5%");
    expect(formatCtr(0)).toBe("0.0%");
    expect(homeBannerImageSrc(row.imageUrl)).toBe(
      "/api/public/home-banners/images/11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222.png",
    );
    expect(homeBannerImageSrc("https://evil.example/x.png")).toBeNull();
  });
});
