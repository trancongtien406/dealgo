import { describe, expect, it } from "vitest";
import { checkChatReviewBody } from "./ops-chat-review-body";

const ID = "6f1c2b7e-4a8d-4c1e-9b2a-1d3e5f7a9b0c";

describe("checkChatReviewBody", () => {
  it("accepts ride/food with a trimmed reason and optional ticket", () => {
    expect(checkChatReviewBody({ kind: "ride", id: ID, reason: "  khiếu nại  " })).toEqual({
      ok: true,
      value: { kind: "ride", id: ID, reason: "khiếu nại" },
    });
    expect(checkChatReviewBody({ kind: "food", id: ID, reason: "khiếu nại", ticketId: ID })).toMatchObject({
      ok: true,
      value: { ticketId: ID },
    });
  });

  it("rejects bad kind, id, ticket and short reason", () => {
    expect(checkChatReviewBody({ kind: "x", id: ID, reason: "khiếu nại" }).ok).toBe(false);
    expect(checkChatReviewBody({ kind: "ride", id: "RIDE-1", reason: "khiếu nại" }).ok).toBe(false);
    expect(checkChatReviewBody({ kind: "ride", id: ID, reason: "khiếu nại", ticketId: "t" }).ok).toBe(false);
    expect(checkChatReviewBody({ kind: "ride", id: ID, reason: "x" }).ok).toBe(false);
    expect(checkChatReviewBody(null).ok).toBe(false);
  });
});
