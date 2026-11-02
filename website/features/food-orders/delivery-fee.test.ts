import { describe, expect, it } from "vitest";
import { mapDeliveryFee } from "@/features/food-orders/mappers";
import {
  categorizeSetting,
  ENUM_SETTING_OPTIONS,
  enumSettingLabel,
  validateSettingValue,
} from "@/features/platform-settings/mappers";
import type { NestFoodOrderView } from "@/features/food-orders/nest-types";

describe("food delivery-fee negotiation (ops)", () => {
  it("maps suggestion vs agreed fee and driver offers", () => {
    const fee = mapDeliveryFee({
      deliveryFareVnd: 20000,
      suggestedDeliveryFareVnd: 16000,
      deliveryFareAgreedAt: "2027-01-06T09:00:00.000Z",
      deliveryFareRaiseCount: 1,
      deliveryOffers: [
        { id: "o1", driverId: "11111111-aaaa", amountVnd: 20000, status: "SELECTED", editCount: 0, createdAt: "" },
        { id: "o2", driverId: "22222222-bbbb", amountVnd: 18000, status: "LOST", editCount: 1, createdAt: "" },
      ],
    } as unknown as NestFoodOrderView);
    expect(fee.suggested).toBe(16000);
    expect(fee.current).toBe(20000);
    expect(fee.agreed).toBe(true);
    expect(fee.offers.map((o) => o.status)).toEqual(["Được chọn", "Không được chọn"]);
  });

  it("legacy orders without negotiation fields still map", () => {
    const fee = mapDeliveryFee({ deliveryFareVnd: 15000 } as unknown as NestFoodOrderView);
    expect(fee).toMatchObject({ suggested: null, current: 15000, agreed: false, offers: [] });
  });

  it("groups the new settings like the backend", () => {
    expect(categorizeSetting("FOOD_FARE_STEP_VND")).toBe("FARE");
    expect(categorizeSetting("FOOD_MAX_FARE_RAISES_PER_ORDER")).toBe("DISPATCH");
    expect(categorizeSetting("FOOD_OFFER_TTL_SECONDS")).toBe("DISPATCH");
  });

  it("shows the fee mode on ops detail", () => {
    const fee = mapDeliveryFee({ deliveryFareVnd: 15000, deliveryFeeMode: "FIXED" } as unknown as NestFoodOrderView);
    expect(fee.mode).toBe("Giá cố định (Fixed)");
    expect(mapDeliveryFee({ deliveryFareVnd: 1, deliveryFeeMode: "NEGOTIATE" } as unknown as NestFoodOrderView).mode).toBe("Cho trả giá (Negotiate)");
  });

  it("FOOD_DELIVERY_FEE_MODE is a NEGOTIATE|FIXED choice under DISPATCH", () => {
    expect(categorizeSetting("FOOD_DELIVERY_FEE_MODE")).toBe("DISPATCH");
    expect(ENUM_SETTING_OPTIONS.FOOD_DELIVERY_FEE_MODE.map((c) => c.value)).toEqual(["NEGOTIATE", "FIXED"]);
    expect(validateSettingValue("FOOD_DELIVERY_FEE_MODE", "fixed")).toBeNull();
    expect(validateSettingValue("FOOD_DELIVERY_FEE_MODE", "AUCTION")).not.toBeNull();
    expect(enumSettingLabel("FOOD_DELIVERY_FEE_MODE", "NEGOTIATE")).toBe("Cho trả giá (Negotiate)");
  });
});
