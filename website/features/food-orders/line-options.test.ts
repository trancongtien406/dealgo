import { describe, expect, it } from "vitest";
import {
  formatLineOptions,
  mapNestFoodOrderToListItem,
} from "@/features/food-orders/mappers";
import type { NestFoodOrderView } from "@/features/food-orders/nest-types";

describe("food order line options (DEC-PROD-033)", () => {
  it("formats the placement snapshot with surcharges", () => {
    expect(
      formatLineOptions([
        { optionId: "o1", groupName: "Size", name: "L", priceDeltaVnd: 10000 },
        { groupName: "Topping", name: "Trân châu", priceDeltaVnd: 8000 },
        { groupName: "Đá", name: "Ít đá", priceDeltaVnd: 0 },
      ]),
    ).toBe("Size: L (+10.000đ) · Topping: Trân châu (+8.000đ) · Đá: Ít đá");
    expect(formatLineOptions(undefined)).toBe("");
    expect(formatLineOptions([])).toBe("");
  });

  it("maps options onto detail lines; legacy lines have none", () => {
    const order: NestFoodOrderView = {
      id: "f1",
      customerId: "c0000000-0000-4000-8000-000000000000",
      storeId: "s0000000-0000-4000-8000-000000000000",
      storeName: "Trà Sữa",
      status: "PLACED",
      deliveryFareVnd: 15000,
      subtotalVnd: 108000,
      totalVnd: 123000,
      dropoff: { lat: 16.07, lng: 108.24, label: "Nhà" },
      assignedDriverId: null,
      lines: [
        {
          itemId: "i1",
          name: "Trà sữa",
          unitPriceVnd: 63000,
          quantity: 1,
          options: [{ groupName: "Size", name: "L", priceDeltaVnd: 10000 }],
        },
        { itemId: "i2", name: "Bánh flan", unitPriceVnd: 45000, quantity: 1 },
      ],
    };
    const row = mapNestFoodOrderToListItem(order);
    expect(row.lines.map((line) => line.options)).toEqual([
      "Size: L (+10.000đ)",
      "",
    ]);
    expect(row.lines[0].unitPriceVnd).toBe(63000);
  });
});
