import {
  INTERVENE_REASON_MAX,
  INTERVENE_REASON_MIN,
} from "@/lib/api/ops-intervene-body";

export const AUTH_METHOD_CODES = [
  "PASSKEY",
  "PHONE_SMS",
  "EMAIL_LOGIN_IDENTIFIER",
] as const;

export type AuthMethodCodeParam = (typeof AUTH_METHOD_CODES)[number];

export function isAuthMethodCode(value: string): value is AuthMethodCodeParam {
  return (AUTH_METHOD_CODES as readonly string[]).includes(value);
}

export type AuthMethodPatchBodyResult =
  | { ok: true; enabled: boolean; reason: string }
  | { ok: false; status: number; message: string };

export async function readAuthMethodPatchBody(
  request: Request,
): Promise<AuthMethodPatchBodyResult> {
  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().includes("application/json")) {
    return { ok: false, status: 415, message: "Yêu cầu không hợp lệ." };
  }
  let json: unknown;
  try {
    json = await request.json();
  } catch {
    return { ok: false, status: 400, message: "Yêu cầu không hợp lệ." };
  }
  if (typeof json !== "object" || json === null) {
    return { ok: false, status: 400, message: "Yêu cầu không hợp lệ." };
  }
  const body = json as { enabled?: unknown; reason?: unknown };
  if (typeof body.enabled !== "boolean") {
    return {
      ok: false,
      status: 400,
      message: "Thiếu trạng thái bật/tắt.",
    };
  }
  if (typeof body.reason !== "string") {
    return { ok: false, status: 400, message: "Nhập lý do thay đổi." };
  }
  const reason = body.reason.trim();
  if (
    reason.length < INTERVENE_REASON_MIN ||
    reason.length > INTERVENE_REASON_MAX
  ) {
    return {
      ok: false,
      status: 400,
      message: `Lý do cần ${INTERVENE_REASON_MIN}–${INTERVENE_REASON_MAX} ký tự.`,
    };
  }
  return { ok: true, enabled: body.enabled, reason };
}
