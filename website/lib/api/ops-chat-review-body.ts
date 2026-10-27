import { isUuid } from "@/lib/api/ops-bff-guards";
import { checkOpsReason } from "@/lib/api/ops-reason-body";

export type ChatReviewKind = "ride" | "food";

export type ChatReviewBody = {
  kind: ChatReviewKind;
  id: string;
  reason: string;
  ticketId?: string;
};

export type ChatReviewBodyCheck =
  | { ok: true; value: ChatReviewBody }
  | { ok: false; message: string };

/** Nest ChatReviewDto (DEC-PROD-056): kind ride|food, uuid id, reason 3–500, optional ticket uuid. */
export function checkChatReviewBody(input: unknown): ChatReviewBodyCheck {
  if (typeof input !== "object" || input === null) {
    return { ok: false, message: "Yêu cầu không hợp lệ." };
  }
  const raw = input as Record<string, unknown>;
  if (raw.kind !== "ride" && raw.kind !== "food") {
    return { ok: false, message: "Yêu cầu không hợp lệ." };
  }
  if (typeof raw.id !== "string" || !isUuid(raw.id)) {
    return { ok: false, message: "Mã không hợp lệ." };
  }
  if (raw.ticketId !== undefined && (typeof raw.ticketId !== "string" || !isUuid(raw.ticketId))) {
    return { ok: false, message: "Mã yêu cầu hỗ trợ không hợp lệ." };
  }
  const reason = checkOpsReason({ reason: raw.reason });
  if (!reason.ok) {
    return reason;
  }
  return {
    ok: true,
    value: {
      kind: raw.kind,
      id: raw.id,
      reason: reason.value.reason,
      ...(typeof raw.ticketId === "string" ? { ticketId: raw.ticketId } : {}),
    },
  };
}
