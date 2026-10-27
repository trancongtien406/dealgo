import { beforeEach, describe, expect, it, vi } from "vitest";

const upstream = vi.fn();
vi.mock("@/lib/api/ops-upstream", () => ({
  fetchOpsUpstream: (args: unknown) => upstream(args),
}));
vi.mock("@/lib/api/ops-people", () => ({
  fetchOpsPeople: async () => ({}),
}));

import { GET as getTransactions } from "@/app/api/ops/transactions/route";
import { GET as getDeliveries } from "@/app/api/ops/deliveries/route";
import { GET as getSettlements } from "@/app/api/ops/settlements/route";
import { GET as getCatalogModeration } from "@/app/api/ops/catalog/moderation/route";

const page = { items: [], total: 0, page: 1, limit: 20 };

function lastSearch(): Record<string, unknown> {
  const call = upstream.mock.calls.at(-1)?.[0] as {
    searchParams?: Record<string, unknown>;
  };
  return call?.searchParams ?? {};
}

describe("Ops list BFF date filters", () => {
  beforeEach(() => {
    upstream.mockReset();
    upstream.mockResolvedValue({ ok: true, status: 200, data: page });
  });

  const cases = [
    ["transactions", getTransactions, "/v1/ops/transactions"],
    ["deliveries", getDeliveries, "/v1/ops/food-orders"],
    ["settlements", getSettlements, "/v1/ops/settlements"],
    ["catalog moderation", getCatalogModeration, "/v1/ops/catalog/moderation"],
  ] as const;

  for (const [name, handler, path] of cases) {
    it(`${name} forwards from/to to ${path}`, async () => {
      await handler(
        new Request(
          `http://admin.test/api/ops/x?page=1&limit=20&from=2026-10-20&to=2026-10-26`,
        ),
      );
      expect(upstream).toHaveBeenCalledTimes(1);
      expect(String(upstream.mock.calls[0][0].path)).toContain(path);
      expect(lastSearch()).toMatchObject({ from: "2026-10-20", to: "2026-10-26" });
    });

    it(`${name} drops invalid dates and swaps a reversed range`, async () => {
      await handler(
        new Request(`http://admin.test/api/ops/x?from=2026-02-30&to=hôm-nay`),
      );
      expect(lastSearch()).not.toHaveProperty("from");
      expect(lastSearch()).not.toHaveProperty("to");
      await handler(
        new Request(`http://admin.test/api/ops/x?from=2026-10-26&to=2026-10-01`),
      );
      expect(lastSearch()).toMatchObject({ from: "2026-10-01", to: "2026-10-26" });
    });
  }

  it("deliveries show the placement time in Vietnam time", async () => {
    upstream.mockResolvedValue({
      ok: true,
      status: 200,
      data: {
        ...page,
        total: 1,
        items: [
          {
            id: "order-1",
            customerId: "c1",
            storeId: "store-1234567890",
            storeName: "Quán A",
            status: "PREPARING",
            deliveryFareVnd: 15000,
            totalVnd: 65000,
            assignedDriverId: null,
            createdAt: "2026-10-26T07:05:00.000Z",
          },
        ],
      },
    });
    const res = await getDeliveries(new Request("http://admin.test/api/ops/deliveries"));
    const body = (await res.json()) as { data: { items: Array<{ time: string }> } };
    expect(body.data.items[0].time).toContain("26/10/2026");
    expect(body.data.items[0].time).toContain("14:05");
  });
});
