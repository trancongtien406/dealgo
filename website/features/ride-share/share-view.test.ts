import { describe, expect, it } from "vitest";
import {
  fetchRideShare,
  nextRideShareRefreshMs,
  parseRideShareView,
  RIDE_SHARE_POLL_MS,
  RIDE_SHARE_RETRY_MS,
  rideShareStatusLabel,
} from "./share-view";

const TOKEN = "abcdefghijklmnopqrstuvwxyzABCDEF";

function respond(status: number, body: unknown): typeof fetch {
  return (async () =>
    new Response(JSON.stringify(body), { status })) as unknown as typeof fetch;
}

describe("ride share view", () => {
  it("rejects malformed tokens without calling the backend", async () => {
    let called = false;
    const result = await fetchRideShare("../etc", (async () => {
      called = true;
      return new Response("{}");
    }) as unknown as typeof fetch);
    expect(result).toEqual({ kind: "not-found" });
    expect(called).toBe(false);
  });

  it("maps 404 and 410", async () => {
    expect(await fetchRideShare(TOKEN, respond(404, {}))).toEqual({
      kind: "not-found",
    });
    expect(await fetchRideShare(TOKEN, respond(410, {}))).toEqual({
      kind: "expired",
    });
    expect(await fetchRideShare(TOKEN, respond(500, {}))).toEqual({
      kind: "unavailable",
    });
  });

  it("parses the envelope and keeps only public fields", async () => {
    const result = await fetchRideShare(
      TOKEN,
      respond(200, {
        success: true,
        data: {
          status: "IN_TRIP",
          pickupLabel: "Chợ Hàn",
          dropoffLabel: "Sân bay Đà Nẵng",
          driver: {
            name: "Nguyễn V. A",
            vehiclePlate: "43A1-123.45",
            vehicleType: "MOTORBIKE",
            ratingAverage: 4.8,
            phone: "+84900000000",
          },
          updatedAt: "2026-10-19T03:00:00.000Z",
          expiresAt: "2026-10-19T15:00:00.000Z",
        },
      }),
    );
    expect(result.kind).toBe("ok");
    if (result.kind !== "ok") return;
    expect(result.view.driver).toEqual({
      name: "Nguyễn V. A",
      vehiclePlate: "43A1-123.45",
      vehicleType: "MOTORBIKE",
      ratingAverage: 4.8,
    });
    expect(rideShareStatusLabel(result.view.status)).toBe(
      "Đang trong chuyến đi",
    );
  });

  it("treats incomplete payloads as unavailable", () => {
    expect(parseRideShareView({ status: "IN_TRIP" })).toBeNull();
    expect(rideShareStatusLabel("WHATEVER")).toBe("Đang cập nhật trạng thái");
  });
});

describe("ride share auto refresh", () => {
  const live = (status: string, expiresAt = "2026-10-19T12:00:00.000Z") =>
    ({
      kind: "ok",
      view: {
        status,
        pickupLabel: "A",
        dropoffLabel: "B",
        driver: null,
        updatedAt: "2026-10-19T03:00:00.000Z",
        expiresAt,
      },
    }) as const;
  const now = new Date("2026-10-19T04:00:00.000Z");

  it("polls every 15 s while the trip is live", () => {
    expect(nextRideShareRefreshMs(live("IN_TRIP"), now)).toBe(RIDE_SHARE_POLL_MS);
    expect(nextRideShareRefreshMs(live("ASSIGNED"), now)).toBe(15_000);
  });

  it("stops when the trip ends or the link expires", () => {
    for (const s of ["COMPLETED", "CANCELLED", "EXPIRED"]) {
      expect(nextRideShareRefreshMs(live(s), now)).toBeNull();
    }
    expect(
      nextRideShareRefreshMs(live("IN_TRIP", "2026-10-19T03:59:00.000Z"), now),
    ).toBeNull();
    expect(nextRideShareRefreshMs({ kind: "not-found" }, now)).toBeNull();
    expect(nextRideShareRefreshMs({ kind: "expired" }, now)).toBeNull();
  });

  it("retries more slowly while the backend is unavailable", () => {
    expect(nextRideShareRefreshMs({ kind: "unavailable" }, now)).toBe(
      RIDE_SHARE_RETRY_MS,
    );
  });
});
