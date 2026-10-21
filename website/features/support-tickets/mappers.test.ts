import { describe, expect, it } from "vitest";
import {
  formatTicketTime,
  nextStatuses,
  relatedLink,
  requesterLine,
} from "@/features/support-tickets/mappers";
import type { SupportTicket } from "@/features/support-tickets/types";

const base: SupportTicket = {
  id: "11111111-1111-4111-8111-111111111111",
  code: "DG-261019-0042",
  channel: "APP",
  category: "RIDE",
  subject: "Cần hỗ trợ về phí chuyến đi",
  status: "OPEN",
  priority: "NORMAL",
  requesterRole: "CUSTOMER",
  requester: { userId: "u1", displayName: "Lan", phone: "0905123456", email: null },
  contactName: null,
  contact: null,
  externalRef: null,
  relatedType: "RIDE",
  relatedId: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeee04826f",
  awaitingRequester: false,
  lastMessageAt: "2026-10-19T02:30:00.000Z",
  resolvedAt: null,
  closedAt: null,
  createdAt: "2026-10-19T02:30:00.000Z",
  updatedAt: "2026-10-19T02:30:00.000Z",
};

describe("support ticket mappers", () => {
  it("uses the app account, else the typed web contact", () => {
    expect(requesterLine(base)).toEqual({ name: "Lan", contact: "0905123456" });
    expect(
      requesterLine({ ...base, channel: "WEB", requester: null, contact: "a@b.vn" }),
    ).toEqual({ name: "Khách vãng lai", contact: "a@b.vn" });
  });

  it("links the related ride or falls back to the typed code", () => {
    expect(relatedLink(base)).toEqual({
      href: `/rides/${base.relatedId}`,
      label: "Chuyến #04826F",
    });
    expect(
      relatedLink({ ...base, relatedType: null, relatedId: null, externalRef: "FOOD-1" }),
    ).toEqual({ href: null, label: "FOOD-1" });
    expect(relatedLink({ ...base, relatedType: null, relatedId: null })).toBeNull();
  });

  it("formats times in Vietnam time and lists allowed status moves", () => {
    expect(formatTicketTime("2026-10-19T02:30:00.000Z")).toContain("09:30");
    expect(formatTicketTime(null)).toBe("—");
    expect(nextStatuses("CLOSED")).toEqual(["IN_PROGRESS"]);
    expect(nextStatuses("OPEN")).toContain("RESOLVED");
  });
});
