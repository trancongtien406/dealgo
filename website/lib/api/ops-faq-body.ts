import {
  INTERVENE_REASON_MAX,
  INTERVENE_REASON_MIN,
} from "@/lib/api/ops-intervene-body";

const FAQ_STATUSES = new Set(["DRAFT", "PUBLISHED", "ARCHIVED"]);
const FAQ_CATEGORIES = new Set(["POLICY", "OPS", "PRODUCT", "TECH"]);
const FAQ_AUDIENCES = new Set(["INTERNAL", "CUSTOMER", "DRIVER", "MERCHANT"]);

function readReason(
  record: Record<string, unknown>,
):
  | { ok: true; reason: string }
  | { ok: false; status: number; message: string } {
  const reason = typeof record.reason === "string" ? record.reason.trim() : "";
  if (
    reason.length < INTERVENE_REASON_MIN ||
    reason.length > INTERVENE_REASON_MAX
  ) {
    return {
      ok: false,
      status: 400,
      message: `Lý do phải từ ${INTERVENE_REASON_MIN}–${INTERVENE_REASON_MAX} ký tự.`,
    };
  }
  return { ok: true, reason };
}

export async function readOpsFaqCreateBody(request: Request): Promise<
  | {
      ok: true;
      payload: {
        openId?: string;
        question: string;
        suggestedAnswer: string;
        category: string;
        status?: string;
        audience?: string;
        sortOrder?: number;
        reason: string;
      };
    }
  | { ok: false; status: number; message: string }
> {
  let json: unknown;
  try {
    json = await request.json();
  } catch {
    return { ok: false, status: 400, message: "Body JSON không hợp lệ." };
  }
  if (!json || typeof json !== "object") {
    return { ok: false, status: 400, message: "Body JSON không hợp lệ." };
  }
  const record = json as Record<string, unknown>;
  const reasonResult = readReason(record);
  if (!reasonResult.ok) {
    return reasonResult;
  }
  const question =
    typeof record.question === "string" ? record.question.trim() : "";
  const suggestedAnswer =
    typeof record.suggestedAnswer === "string"
      ? record.suggestedAnswer.trim()
      : "";
  const category =
    typeof record.category === "string" ? record.category.trim() : "";
  if (question.length < 3 || question.length > 500) {
    return {
      ok: false,
      status: 400,
      message: "Câu hỏi phải từ 3–500 ký tự.",
    };
  }
  if (suggestedAnswer.length < 3 || suggestedAnswer.length > 8000) {
    return {
      ok: false,
      status: 400,
      message: "Câu trả lời gợi ý phải từ 3–8000 ký tự.",
    };
  }
  if (!FAQ_CATEGORIES.has(category)) {
    return { ok: false, status: 400, message: "Category không hợp lệ." };
  }
  const status =
    typeof record.status === "string" ? record.status.trim() : undefined;
  if (status && !FAQ_STATUSES.has(status)) {
    return { ok: false, status: 400, message: "Status không hợp lệ." };
  }
  const audience =
    typeof record.audience === "string" ? record.audience.trim() : undefined;
  if (audience && !FAQ_AUDIENCES.has(audience)) {
    return { ok: false, status: 400, message: "Đối tượng FAQ không hợp lệ." };
  }
  const openId =
    typeof record.openId === "string" && record.openId.trim()
      ? record.openId.trim()
      : undefined;
  const sortOrder =
    typeof record.sortOrder === "number" && Number.isFinite(record.sortOrder)
      ? record.sortOrder
      : undefined;
  return {
    ok: true,
    payload: {
      openId,
      question,
      suggestedAnswer,
      category,
      status,
      audience,
      sortOrder,
      reason: reasonResult.reason,
    },
  };
}

export async function readOpsFaqPatchBody(request: Request): Promise<
  | {
      ok: true;
      payload: Record<string, unknown>;
    }
  | { ok: false; status: number; message: string }
> {
  let json: unknown;
  try {
    json = await request.json();
  } catch {
    return { ok: false, status: 400, message: "Body JSON không hợp lệ." };
  }
  if (!json || typeof json !== "object") {
    return { ok: false, status: 400, message: "Body JSON không hợp lệ." };
  }
  const record = json as Record<string, unknown>;
  const reasonResult = readReason(record);
  if (!reasonResult.ok) {
    return reasonResult;
  }
  const payload: Record<string, unknown> = { reason: reasonResult.reason };
  if (typeof record.question === "string") {
    payload.question = record.question.trim();
  }
  if (typeof record.suggestedAnswer === "string") {
    payload.suggestedAnswer = record.suggestedAnswer.trim();
  }
  if (typeof record.category === "string") {
    if (!FAQ_CATEGORIES.has(record.category.trim())) {
      return { ok: false, status: 400, message: "Category không hợp lệ." };
    }
    payload.category = record.category.trim();
  }
  if (typeof record.status === "string") {
    if (!FAQ_STATUSES.has(record.status.trim())) {
      return { ok: false, status: 400, message: "Status không hợp lệ." };
    }
    payload.status = record.status.trim();
  }
  if (typeof record.audience === "string") {
    if (!FAQ_AUDIENCES.has(record.audience.trim())) {
      return { ok: false, status: 400, message: "Đối tượng FAQ không hợp lệ." };
    }
    payload.audience = record.audience.trim();
  }
  if (typeof record.openId === "string") {
    payload.openId = record.openId.trim() || null;
  }
  if (
    typeof record.sortOrder === "number" &&
    Number.isFinite(record.sortOrder)
  ) {
    payload.sortOrder = record.sortOrder;
  }
  return { ok: true, payload };
}
