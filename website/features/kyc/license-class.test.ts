import { describe, expect, it } from "vitest";
import {
  carDocsRequiredMessage,
  licenseAllowsVehicleClass,
  licenseMismatchMessage,
} from "./license-class";

describe("KYC licence class (t88u)", () => {
  it("only offers vehicle classes the declared licence covers", () => {
    expect(licenseAllowsVehicleClass("A1", "MOTORBIKE", false)).toBe(true);
    expect(licenseAllowsVehicleClass("A1", "CAR_4", false)).toBe(false);
    expect(licenseAllowsVehicleClass("b2", "CAR_7", false)).toBe(true);
    expect(licenseAllowsVehicleClass("B", "MOTORBIKE", false)).toBe(false);
  });

  it("does not block when no licence was declared (quick registration)", () => {
    expect(licenseAllowsVehicleClass("A1", "CAR_4", true)).toBe(true);
    expect(licenseAllowsVehicleClass("", "CAR_4", false)).toBe(true);
  });

  it("turns the API mismatch error into Vietnamese guidance", () => {
    const vi = licenseMismatchMessage("Licence class A1 does not cover CAR_4");
    expect(vi).toContain("Hạng GPLX A1 không được lái Ô tô 4 chỗ");
    expect(vi).toContain("Yêu cầu bổ sung");
    expect(licenseMismatchMessage("Something else")).toBeNull();
  });
});

describe("carDocsRequiredMessage (t90u)", () => {
  it("maps the approve error to Vietnamese with the next step", () => {
    const vi = carDocsRequiredMessage("Car KYC documents required: VEHICLE_INSURANCE");
    expect(vi).toContain("bảo hiểm xe");
    expect(vi).toContain("Yêu cầu bổ sung");
    expect(carDocsRequiredMessage("Other")).toBeNull();
  });
});
