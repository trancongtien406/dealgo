import { beforeEach, describe, expect, it, vi } from "vitest";

const fetchOpsUpstream = vi.fn();

vi.mock("@/lib/api/ops-upstream", () => ({
  fetchOpsUpstream: (...args: unknown[]) => fetchOpsUpstream(...args),
}));

const { GET } = await import("./route");
const { GET: GET_DRIVERS } = await import("../drivers/route");

const CUSTOMER = "11111111-1111-4111-8111-111111111111";
const DRIVER = "22222222-2222-4222-8222-222222222222";

const ride = {
  id: "33333333-3333-4333-8333-333333333333",
  status: "ASSIGNED",
  customerId: CUSTOMER,
  assignedDriverId: DRIVER,
  pickup: { lat: 16.06, lng: 108.2, label: "A" },
  dropoff: { lat: 16.07, lng: 108.24, label: "B" },
  offers: [{ id: "o1", driverId: DRIVER, amountVnd: 1, kind: "BID", status: "SELECTED", expiresAt: "" }],
};

const people = [
  {
    id: CUSTOMER,
    displayName: "Nguyễn Văn A",
    phoneMasked: "0901***678",
    vehiclePlate: null,
    vehicleType: null,
    ratingAverage: null,
    ratingCount: 0,
  },
  {
    id: DRIVER,
    displayName: "Trần B",
    phoneMasked: "0912***111",
    vehiclePlate: "43B1-12345",
    vehicleType: "Xe máy",
    ratingAverage: 4.8,
    ratingCount: 3,
  },
];

describe("ops BFF people enrichment", () => {
  beforeEach(() => {
    fetchOpsUpstream.mockReset();
  });

  it("adds customer/driver profiles to rides with one batch lookup", async () => {
    fetchOpsUpstream.mockImplementation(async ({ path }: { path: string }) =>
      path === "/v1/ops/people"
        ? { ok: true, status: 200, data: people }
        : { ok: true, status: 200, data: { items: [ride], page: 1, limit: 20, total: 1 } },
    );
    const res = await GET(new Request("http://localhost/api/ops/rides"));
    const body = await res.json();
    const item = body.data.items[0];
    expect(item.customerProfile.displayName).toBe("Nguyễn Văn A");
    expect(item.driverProfile.vehiclePlate).toBe("43B1-12345");
    expect(item.offers[0].driverProfile.displayName).toBe("Trần B");
    const peopleCalls = fetchOpsUpstream.mock.calls.filter(
      ([init]) => init.path === "/v1/ops/people",
    );
    expect(peopleCalls).toHaveLength(1);
    expect(peopleCalls[0][0].searchParams.ids.split(",").sort()).toEqual(
      [CUSTOMER, DRIVER].sort(),
    );
  });

  it("still returns rows when the people lookup fails", async () => {
    fetchOpsUpstream.mockImplementation(async ({ path }: { path: string }) =>
      path === "/v1/ops/people"
        ? { ok: false, status: 502, message: "down" }
        : { ok: true, status: 200, data: { items: [ride], page: 1, limit: 20, total: 1 } },
    );
    const res = await GET(new Request("http://localhost/api/ops/rides"));
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.data.items[0].customerProfile).toBeNull();
  });

  it("adds vehicle/rating profile to driver rows", async () => {
    fetchOpsUpstream.mockImplementation(async ({ path }: { path: string }) =>
      path === "/v1/ops/people"
        ? { ok: true, status: 200, data: people }
        : {
            ok: true,
            status: 200,
            data: { items: [{ id: DRIVER, displayName: "Trần B", grants: [], presence: null }], page: 1, limit: 20, total: 1 },
          },
    );
    const res = await GET_DRIVERS(new Request("http://localhost/api/ops/drivers"));
    const body = await res.json();
    expect(body.data.items[0].profile.vehicleType).toBe("Xe máy");
  });
});
