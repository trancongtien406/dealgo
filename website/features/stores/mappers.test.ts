import { describe, expect, it } from "vitest";

import {
  mapNestStoreToListItem,
  storeAcceptSummary,
  storeSaleFromNest,
} from "@/features/stores/mappers";
import type { NestOpsStore } from "@/features/stores/nest-types";

const base: NestOpsStore = {
  id: "11111111-2222-4333-8444-555555555555",
  name: "Bún Bò Huế O Cò",
  ownerId: "99999999-2222-4333-8444-555555555555",
  lat: null,
  lng: null,
  createdAt: "2026-10-19T00:00:00.000Z",
  itemCount: 3,
};

describe("store intake status (DEC-PROD-026/027)", () => {
  it("prefers the live backend state over the legacy sale field", () => {
    expect(
      storeSaleFromNest({
        ...base,
        serviceMode: "PAUSED",
        openNow: false,
        closedReason: "PAUSED",
      }),
    ).toBe("PAUSED");
    expect(
      storeSaleFromNest({
        ...base,
        serviceMode: "OPEN",
        openNow: false,
        closedReason: "CLOSED",
      }),
    ).toBe("CLOSED");
    expect(
      storeSaleFromNest({
        ...base,
        serviceMode: "BUSY",
        openNow: true,
        closedReason: null,
      }),
    ).toBe("BUSY");
    expect(
      storeSaleFromNest({
        ...base,
        serviceMode: "OPEN",
        openNow: true,
        closedReason: null,
      }),
    ).toBe("OPEN");
    expect(storeSaleFromNest({ ...base, sale: "SUSPENDED" })).toBe("SUSPENDED");
    expect(storeSaleFromNest(base)).toBeNull();
  });

  it("carries the auto-resume time to the row", () => {
    const row = mapNestStoreToListItem({
      ...base,
      serviceMode: "PAUSED",
      serviceModeUntil: "2026-10-20T03:30:00.000Z",
      openNow: false,
      closedReason: "PAUSED",
    });
    expect(row.sale).toBe("PAUSED");
    expect(row.serviceModeUntil).toBe("2026-10-20T03:30:00.000Z");
    expect(row.acceptSummary).toBeNull();
    expect(row.prepMinutes).toBeNull();
  });

  it("flags stores without a map pin", () => {
    expect(
      mapNestStoreToListItem({ ...base, lat: null, lng: null }).locationMissing,
    ).toBe(true);
    expect(
      mapNestStoreToListItem({ ...base, lat: 10.77, lng: 106.7 })
        .locationMissing,
    ).toBe(false);
  });
});

describe("storeAcceptSummary (DEC-PROD-028)", () => {
  it("names the mode and the kitchen cap", () => {
    expect(
      storeAcceptSummary({
        acceptSettings: {
          acceptMode: "AUTO",
          maxActiveOrders: 8,
          defaultPrepMinutes: 20,
          busyExtraMinutes: 15,
        },
      }),
    ).toBe("Tự động · tối đa 8 đơn đang xử lý");
    expect(
      storeAcceptSummary({
        acceptSettings: {
          acceptMode: "MANUAL",
          maxActiveOrders: null,
          defaultPrepMinutes: 15,
          busyExtraMinutes: 15,
        },
      }),
    ).toBe("Thủ công · không giới hạn đơn");
    expect(storeAcceptSummary({})).toBeNull();
  });
});
