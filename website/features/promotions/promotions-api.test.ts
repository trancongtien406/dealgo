import { describe, it, expect } from "vitest";
import {
  promotionCampaignStatusLabel,
  promotionCampaignStatusTone,
} from "./mappers";

describe("Promotions Mappers", () => {
  it("maps ACTIVE status to correct label and tone", () => {
    expect(promotionCampaignStatusLabel("ACTIVE")).toBe("Đang hoạt động");
    expect(promotionCampaignStatusTone("ACTIVE")).toBe("success");
  });

  it("maps PAUSED status to correct label and tone", () => {
    expect(promotionCampaignStatusLabel("PAUSED")).toBe("Tạm dừng");
    expect(promotionCampaignStatusTone("PAUSED")).toBe("food");
  });

  it("maps SCHEDULED status to correct label and tone", () => {
    expect(promotionCampaignStatusLabel("SCHEDULED")).toBe("Đã lên lịch");
    expect(promotionCampaignStatusTone("SCHEDULED")).toBe("delivery");
  });

  it("maps CANCELLED status to correct label and tone", () => {
    expect(promotionCampaignStatusLabel("CANCELLED")).toBe("Đã hủy");
    expect(promotionCampaignStatusTone("CANCELLED")).toBe("danger");
  });
});
