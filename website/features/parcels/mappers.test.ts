import { describe, expect, it } from "vitest";
import {
  isParcelOutcomeFilter,
  isParcelPhotoKind,
  mapNestParcelToListItem,
  parcelStageLabel,
} from "@/features/parcels/mappers";
import type { NestParcelListRow } from "@/features/parcels/types";

const row: NestParcelListRow = {
  rideId: "11111111-1111-4111-8111-111111111111",
  createdAt: "2026-10-30T03:00:00.000Z",
  sizeClass: "M",
  weightKg: 12,
  note: null,
  payer: "SENDER",
  surchargeVnd: 0,
  sender: { name: "An", phone: "0901234567" },
  recipient: null,
  outcome: "PENDING",
  failReason: null,
  failNote: null,
  photos: { item: false, pickup: true, delivery: false, return: false },
  pickedUpAt: "2026-10-30T03:10:00.000Z",
  deliveredAt: null,
  failedAt: null,
  returnedAt: null,
  ride: {
    status: "IN_TRIP",
    vehicleClassCode: "MOTORBIKE",
    pickupLabel: "A",
    dropoffLabel: "B",
    agreedFareVnd: 45000,
    offeredFareVnd: 40000,
    serviceRegionCode: "HCM",
  },
};

describe("parcel mappers (DEC-PROD-071)", () => {
  it("maps a list row", () => {
    expect(mapNestParcelToListItem(row)).toMatchObject({
      id: row.rideId,
      route: "A → B",
      fareVnd: 45000,
      weightLabel: "12 kg",
      sender: "An · 0901234567",
      recipient: "—",
      outcomeLabel: "Đang giao",
    });
  });

  it("labels stages", () => {
    expect(parcelStageLabel({ outcome: "PENDING", pickedUpAt: null })).toBe("Chờ lấy hàng");
    expect(parcelStageLabel({ outcome: "RETURNING", pickedUpAt: "x" })).toBe("Đang hoàn hàng");
  });

  it("guards filter and photo kinds", () => {
    expect(isParcelOutcomeFilter("DELIVERED")).toBe(true);
    expect(isParcelOutcomeFilter("PICKED_UP")).toBe(false);
    expect(isParcelPhotoKind("delivery")).toBe(true);
    expect(isParcelPhotoKind("../x")).toBe(false);
  });

  it("falls back when the ride is missing", () => {
    expect(mapNestParcelToListItem({ ...row, ride: null })).toMatchObject({ route: "—", fareVnd: null });
  });
});
