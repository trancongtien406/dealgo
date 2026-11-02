import { describe, expect, it } from "vitest";
import {
  BOOLEAN_SETTING_KEYS,
  categorizeSetting,
  enrichPlatformSetting,
  validateSettingValue,
} from "@/features/platform-settings/mappers";

describe("commission settings", () => {
  it("accepts 0–100 with at most two decimals", () => {
    for (const ok of ["0", "12", "12.5", "12.55", "100"]) {
      expect(validateSettingValue("RIDE_COMMISSION_BIKE_PERCENT", ok)).toBeNull();
    }
    for (const bad of ["-1", "100.01", "12.345", "abc", "", "1e1"]) {
      expect(validateSettingValue("FOOD_DRIVER_COMMISSION_PERCENT", bad)).not.toBeNull();
    }
  });

  it("checks the rating window as whole days", () => {
    expect(validateSettingValue("RATING_WINDOW_DAYS", "7")).toBeNull();
    expect(validateSettingValue("RATING_WINDOW_DAYS", "0")).not.toBeNull();
    expect(validateSettingValue("RATING_WINDOW_DAYS", "2.5")).not.toBeNull();
    expect(validateSettingValue("RIDE_PICKUP_CODE_MAX_ATTEMPTS", "5")).toBeNull();
    expect(validateSettingValue("RIDE_PICKUP_CODE_MAX_ATTEMPTS", "0")).not.toBeNull();
    expect(validateSettingValue("RIDE_PICKUP_CODE_MAX_ATTEMPTS", "21")).not.toBeNull();
    expect(validateSettingValue("RATING_STORE_MIN_COUNT", "3")).toBeNull();
    expect(validateSettingValue("RATING_STORE_MIN_COUNT", "51")).not.toBeNull();
    expect(validateSettingValue("RIDE_MIN_FARE_VND", "anything")).toBeNull();
  });

  it("labels and groups the new keys", () => {
    expect(categorizeSetting("RIDE_COMMISSION_CAR_PERCENT")).toBe("FARE");
    expect(categorizeSetting("RATING_WINDOW_DAYS")).toBe("DISPATCH");
    expect(categorizeSetting("RIDE_PICKUP_CODE_MAX_ATTEMPTS")).toBe("DISPATCH");
    expect(categorizeSetting("SUPPORT_TICKET_MAX_OPEN_PER_USER")).toBe("SUPPORT");
    expect(validateSettingValue("SUPPORT_TICKET_TEXT_MAX_CHARS", "100")).not.toBeNull();
    expect(validateSettingValue("SUPPORT_TICKET_TEXT_MAX_CHARS", "2000")).toBeNull();
    expect(categorizeSetting("UPLOAD_MAX_FILE_KB")).toBe("SUPPORT");
    expect(validateSettingValue("UPLOAD_MAX_FILE_KB", "99")).not.toBeNull();
    expect(validateSettingValue("UPLOAD_MAX_FILE_KB", "4096")).toBeNull();
    expect(validateSettingValue("UPLOAD_MAX_FILE_KB", "6000")).not.toBeNull();
    expect(categorizeSetting("UPLOAD_ORPHAN_MAX_AGE_HOURS")).toBe("SUPPORT");
    expect(validateSettingValue("UPLOAD_ORPHAN_MAX_AGE_HOURS", "12")).not.toBeNull();
    expect(validateSettingValue("UPLOAD_ORPHAN_MAX_AGE_HOURS", "72")).toBeNull();
    expect(validateSettingValue("UPLOAD_ORPHAN_MAX_AGE_HOURS", "3000")).not.toBeNull();
    expect(validateSettingValue("UPLOAD_ALLOWED_TYPES", '["image/jpeg","application/pdf"]')).toBeNull();
    expect(validateSettingValue("UPLOAD_ALLOWED_TYPES", "[]")).not.toBeNull();
    expect(validateSettingValue("UPLOAD_ALLOWED_TYPES", '["image/gif"]')).not.toBeNull();
    expect(validateSettingValue("UPLOAD_ALLOWED_TYPES", '["image/png","image/png"]')).not.toBeNull();
    expect(validateSettingValue("UPLOAD_ALLOWED_TYPES", "image/png")).not.toBeNull();
    const row = enrichPlatformSetting({
      key: "FOOD_DRIVER_COMMISSION_PERCENT",
      value: "0",
      valueType: "number",
      source: "db",
      openIds: [],
      updatedAt: null,
      updatedByUserId: null,
    });
    expect(row.label).toBe("Hoa hồng tài xế giao đồ ăn (%)");
  });
});

describe("food code settings (DEC-PROD-036)", () => {
  it("validates booleans and attempts and groups them under dispatch", () => {
    expect(validateSettingValue("FOOD_DELIVERY_CODE_REQUIRED", "true")).toBeNull();
    expect(validateSettingValue("FOOD_HANDOVER_CODE_REQUIRED", " false ")).toBeNull();
    expect(validateSettingValue("FOOD_DELIVERY_CODE_REQUIRED", "yes")).not.toBeNull();
    expect(validateSettingValue("FOOD_DELIVERY_CODE_MAX_ATTEMPTS", "5")).toBeNull();
    expect(validateSettingValue("FOOD_DELIVERY_CODE_MAX_ATTEMPTS", "0")).not.toBeNull();
    for (const key of [
      "FOOD_DELIVERY_CODE_REQUIRED",
      "FOOD_DELIVERY_CODE_MAX_ATTEMPTS",
      "FOOD_HANDOVER_CODE_REQUIRED",
    ]) {
      expect(categorizeSetting(key)).toBe("DISPATCH");
    }
  });
});

describe("dispatch settings", () => {
  it("labels the seed-only Ride price settings and points to vehicle classes", () => {
    const row = enrichPlatformSetting({
      key: "RIDE_MIN_FARE_VND",
      value: "10000",
      valueType: "number",
      source: "db",
      openIds: [],
      updatedAt: null,
      updatedByUserId: null,
    });
    expect(row.label).toContain("chỉ để tạo hạng xe lần đầu");
    expect(row.hint).toContain("Loại xe");
  });

  it("validates ranges and booleans and groups the new keys", () => {
    expect(validateSettingValue("RIDE_REQUEST_WINDOW_SECONDS", "300")).toBeNull();
    expect(validateSettingValue("RIDE_REQUEST_WINDOW_SECONDS", "30")).not.toBeNull();
    expect(validateSettingValue("RIDE_COUNTER_MAX_PERCENT_OF_OFFER", "99")).not.toBeNull();
    expect(validateSettingValue("DRIVER_DEBT_LIMIT_VND", "200000")).toBeNull();
    expect(validateSettingValue("SERVICE_ZONE_ENFORCED", "true")).toBeNull();
    expect(validateSettingValue("DISPATCH_REQUIRE_FRESH_PRESENCE", "on")).not.toBeNull();
    expect(categorizeSetting("RIDE_MAX_OFFER_EDITS_PER_DRIVER")).toBe("DISPATCH");
    expect(categorizeSetting("RIDE_NO_SHOW_WAIT_MINUTES")).toBe("DISPATCH");
    expect(categorizeSetting("FOOD_MERCHANT_ACCEPT_TIMEOUT_MINUTES")).toBe("DISPATCH");
    expect(categorizeSetting("RIDE_CANCEL_FEE_BIKE_VND")).toBe("FARE");
    expect(categorizeSetting("RIDE_FREE_CANCEL_MINUTES")).toBe("FARE");
    expect(categorizeSetting("RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE")).toBe("FARE");
    expect(categorizeSetting("DRIVER_DEBT_LIMIT_VND")).toBe("ZONE_PAYMENT");
    expect(categorizeSetting("SERVICE_ZONE_ENFORCED")).toBe("ZONE_PAYMENT");
  });
});

describe("commission split and settlement cycle", () => {
  it("validates the cycle as 1–31 whole days and groups money keys under FARE", () => {
    expect(validateSettingValue("MERCHANT_SETTLEMENT_CYCLE_DAYS", "7")).toBeNull();
    expect(validateSettingValue("MERCHANT_SETTLEMENT_CYCLE_DAYS", "0")).not.toBeNull();
    expect(validateSettingValue("MERCHANT_SETTLEMENT_CYCLE_DAYS", "32")).not.toBeNull();
    expect(validateSettingValue("RIDE_COMMISSION_CAR_PERCENT", "12.5")).toBeNull();
    for (const key of [
      "RIDE_COMMISSION_BIKE_PERCENT",
      "RIDE_COMMISSION_CAR_PERCENT",
      "FOOD_DRIVER_COMMISSION_PERCENT",
      "FOOD_MERCHANT_COMMISSION_PERCENT",
      "MERCHANT_SETTLEMENT_CYCLE_DAYS",
    ]) {
      expect(categorizeSetting(key)).toBe("FARE");
      const row = enrichPlatformSetting({
        key,
        value: "0",
        valueType: "number",
        source: "db",
        openIds: [],
        updatedAt: null,
        updatedByUserId: null,
      });
      expect(row.label).not.toBe(key);
    }
  });
});

describe("voice calls toggle", () => {
  it("is a Bật / Tắt switch grouped under SUPPORT", () => {
    expect(BOOLEAN_SETTING_KEYS.has("VOICE_CALLS_ENABLED")).toBe(true);
    expect(categorizeSetting("VOICE_CALLS_ENABLED")).toBe("SUPPORT");
  });
});

describe("maps provider settings", () => {
  it("accept only mapbox or google", () => {
    expect(validateSettingValue("MAPS_SEARCH_PROVIDER", "google")).toBeNull();
    expect(validateSettingValue("MAPS_ROUTE_PROVIDER", "mapbox")).toBeNull();
    expect(validateSettingValue("MAPS_REVERSE_PROVIDER", "here")).not.toBeNull();
  });
});

describe("intercity + offer TTL settings (t73u)", () => {
  it("validates the offer TTL range 10–120 s", () => {
    expect(validateSettingValue("RIDE_OFFER_TTL_SECONDS", "20")).toBeNull();
    expect(validateSettingValue("RIDE_OFFER_TTL_SECONDS", "9")).not.toBeNull();
    expect(validateSettingValue("RIDE_OFFER_TTL_SECONDS", "121")).not.toBeNull();
  });
  it("treats the intercity flag as a switch and validates its JSON", () => {
    expect(BOOLEAN_SETTING_KEYS.has("RIDE_INTERCITY_ENABLED")).toBe(true);
    expect(categorizeSetting("RIDE_INTERCITY_ENABLED")).toBe("DISPATCH");
    expect(categorizeSetting("RIDE_INTERCITY_PRICING")).toBe("FARE");
    expect(validateSettingValue("RIDE_INTERCITY_VEHICLE_CLASSES", '["CAR_4"]')).toBeNull();
    expect(validateSettingValue("RIDE_INTERCITY_VEHICLE_CLASSES", '["car 4"]')).not.toBeNull();
    expect(validateSettingValue("RIDE_INTERCITY_PRICING", '{"CAR_4":{"perKmVnd":9000}}')).toBeNull();
    expect(validateSettingValue("RIDE_INTERCITY_PRICING", '{"CAR_4":{"minFareVnd":5,"maxFareVnd":1}}')).not.toBeNull();
    expect(validateSettingValue("RIDE_INTERCITY_MAX_KM", "3001")).not.toBeNull();
  });
});
