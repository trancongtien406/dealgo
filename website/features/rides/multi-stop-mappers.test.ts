import { describe, expect, it } from "vitest";
import { mapNestRideToListItem, mapRideStops, rideStopStateLabel } from "@/features/rides/mappers";
import type { NestRideView } from "@/features/rides/nest-types";
import { BOOLEAN_SETTING_KEYS } from "@/features/platform-settings/mappers";

const ride: NestRideView = {
  id: "ride-ms",
  status: "IN_TRIP",
  pickup: { lat: 16.06, lng: 108.2, label: "Pickup" },
  dropoff: { lat: 16.07, lng: 108.24, label: "Dropoff" },
  offeredFareVnd: 60000,
  referenceFareVnd: 60000,
  agreedFareVnd: 60000,
  cashDueVnd: 63000,
  waitFeeVnd: 3000,
  assignedDriverId: "d",
  selectedOfferId: null,
  expiresAt: "2026-11-01T10:00:00.000Z",
  stops: [
    { seq: 2, lat: 16.065, lng: 108.22, label: "Stop B", arrivedAt: null, departedAt: null },
    {
      seq: 1,
      lat: 16.062,
      lng: 108.21,
      label: "Stop A",
      arrivedAt: "2026-11-01T10:05:00.000Z",
      departedAt: "2026-11-01T10:12:00.000Z",
    },
  ],
};

describe("multi-stop admin mappers", () => {
  it("orders stops and labels their state", () => {
    const stops = mapRideStops(ride);
    expect(stops.map((s) => s.label)).toEqual(["Stop A", "Stop B"]);
    expect(stops[0]!.state).toBe("DEPARTED");
    expect(rideStopStateLabel(stops[0]!)).toMatch(/^Đã rời /);
    expect(rideStopStateLabel(stops[1]!)).toBe("Chưa đến");
  });

  it("keeps single-destination payloads working", () => {
    const item = mapNestRideToListItem({ ...ride, stops: undefined, waitFeeVnd: undefined });
    expect(item.stops).toEqual([]);
    expect(item.waitFeeVnd).toBe(0);
  });

  it("carries the wait fee into the list item", () => {
    expect(mapNestRideToListItem(ride).waitFeeVnd).toBe(3000);
  });

  it("offers Bật / Tắt for the multi-stop flags", () => {
    expect(BOOLEAN_SETTING_KEYS.has("RIDE_MULTI_STOP_BIKE_ENABLED")).toBe(true);
    expect(BOOLEAN_SETTING_KEYS.has("RIDE_MULTI_STOP_CAR_ENABLED")).toBe(true);
  });
});
