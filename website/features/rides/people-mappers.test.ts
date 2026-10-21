import { describe, expect, it } from "vitest";
import { mapNestRideToListItem } from "@/features/rides/mappers";
import { completionRateLabel, mapNestDriverToListItem } from "@/features/drivers/mappers";
import { mapNestFoodOrderToListItem } from "@/features/food-orders/mappers";
import type { NestRideView } from "@/features/rides/nest-types";
import type { NestOpsDriver } from "@/features/drivers/nest-types";
import type { NestFoodOrderView } from "@/features/food-orders/nest-types";

const person = {
  id: "d",
  displayName: "Trần B",
  phoneMasked: "0912***111",
  vehiclePlate: "43B1-12345",
  vehicleType: "Xe máy",
  ratingAverage: 4.8,
  ratingCount: 3,
  completedJobs: 11,
  finishedJobs: 12,
  completionRate: 0.917,
};

const baseRide: NestRideView = {
  id: "ride-1",
  status: "ASSIGNED",
  pickup: { lat: 16.06, lng: 108.2, label: "12 Lê Lợi, Hải Châu" },
  dropoff: { lat: 16.07, lng: 108.24, label: "Mỹ Khê, Sơn Trà" },
  offeredFareVnd: 50000,
  referenceFareVnd: 50000,
  agreedFareVnd: 48000,
  assignedDriverId: "d0000000-0000-4000-8000-000000000000",
  selectedOfferId: null,
  expiresAt: "2026-10-20T02:00:00.000Z",
};

describe("Admin rows use real people + coordinates", () => {
  it("ride rows show the real customer, masked phone, driver and plate", () => {
    const row = mapNestRideToListItem({
      ...baseRide,
      customerId: "c0000000-0000-4000-8000-000000000000",
      customerProfile: { ...person, id: "c", displayName: "Nguyễn Văn A", phoneMasked: "0901***678" },
      driverProfile: person,
    });
    expect(row.customer).toBe("Nguyễn Văn A");
    expect(row.phone).toBe("0901***678");
    expect(row.driver).toBe("Trần B");
    expect(row.plate).toBe("43B1-12345");
    expect(row.pickupPoint).toEqual({ lat: 16.06, lng: 108.2 });
    expect(row.dropoffPoint).toEqual({ lat: 16.07, lng: 108.24 });
  });

  it("falls back to id tags / dashes, never an invented name", () => {
    const row = mapNestRideToListItem({ ...baseRide, customerId: "c0000000-0000-4000-8000-000000000000" });
    expect(row.customer).toBe("KH · c0000000");
    expect(row.phone).toBe("—");
    expect(row.driver).toBe("TX · d0000000");
    expect(row.plate).toBe("—");
    expect(mapNestRideToListItem(baseRide).customer).toBe("—");
  });

  it("driver rows take services from presence and vehicle/rating from the profile", () => {
    const driver: NestOpsDriver = {
      id: "d",
      displayName: "Trần B",
      phone: null,
      email: null,
      phoneVerifiedAt: null,
      emailVerifiedAt: null,
      createdAt: "",
      grants: [],
      presence: { online: true, lat: null, lng: null, updatedAt: "", rideEnabled: true, foodEnabled: true },
      profile: person,
    };
    const row = mapNestDriverToListItem(driver);
    expect(row.service).toBe("Xe · Đồ ăn");
    expect(row.plate).toBe("43B1-12345");
    expect(row.vehicleKind).toBe("Xe máy");
    expect(row.rating).toBe(4.8);
    expect(row.trips).toBe(11);
    expect(row.finishedJobs).toBe(12);
    expect(completionRateLabel(row.completionRate)).toBe("92%");
    const bare = mapNestDriverToListItem({ ...driver, presence: null, profile: null });
    expect([bare.service, bare.plate, bare.rating]).toEqual(["—", "—", null]);
    expect([bare.trips, bare.completionRate]).toEqual([null, null]);
    expect(completionRateLabel(bare.completionRate)).toBe("—");
  });

  it("food rows carry the store pickup and customer dropoff points", () => {
    const order: NestFoodOrderView = {
      id: "f1",
      customerId: "c0000000-0000-4000-8000-000000000000",
      storeId: "s0000000-0000-4000-8000-000000000000",
      storeName: "Bếp Hàn",
      status: "PREPARING",
      deliveryFareVnd: 15000,
      subtotalVnd: 50000,
      totalVnd: 65000,
      dropoff: { lat: 16.07, lng: 108.24, label: "Nhà" },
      pickup: { lat: 16.05, lng: 108.21, label: "Quán" },
      assignedDriverId: null,
      lines: [],
    };
    const row = mapNestFoodOrderToListItem(order);
    expect(row.pickupPoint).toEqual({ lat: 16.05, lng: 108.21 });
    expect(row.dropoffPoint).toEqual({ lat: 16.07, lng: 108.24 });
    expect(mapNestFoodOrderToListItem({ ...order, pickup: null }).pickupPoint).toBeNull();
  });
});
