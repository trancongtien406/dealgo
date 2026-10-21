import { describe, expect, it } from "vitest";
import {
  categorizeSetting,
  enrichPlatformSetting,
  validateSettingValue,
} from "@/features/platform-settings/mappers";

describe("platform fee settings", () => {
  it("accepts 0–100 with at most two decimals", () => {
    for (const ok of ["0", "12", "12.5", "12.55", "100"]) {
      expect(validateSettingValue("PLATFORM_FEE_RIDE_PERCENT", ok)).toBeNull();
    }
    for (const bad of ["-1", "100.01", "12.345", "abc", "", "1e1"]) {
      expect(validateSettingValue("PLATFORM_FEE_FOOD_PERCENT", bad)).not.toBeNull();
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
    expect(categorizeSetting("PLATFORM_FEE_RIDE_PERCENT")).toBe("FARE");
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
      key: "PLATFORM_FEE_FOOD_PERCENT",
      value: "0",
      valueType: "number",
      source: "db",
      openIds: [],
      updatedAt: null,
      updatedByUserId: null,
    });
    expect(row.label).toBe("Phí nền tảng giao đồ ăn (%)");
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
