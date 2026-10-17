/** Nest OpsInterveneDto: reason 3–500 chars after trim. */
export const INTERVENE_REASON_MIN = 3;
export const INTERVENE_REASON_MAX = 500;

export type InterveneReasonBodyResult =
  { ok: true; reason: string } | { ok: false; status: number; message: string };

export async function readInterveneReasonBody(
  request: Request,
): Promise<InterveneReasonBodyResult> {
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
  if (
    typeof json !== "object" ||
    json === null ||
    typeof (json as { reason?: unknown }).reason !== "string"
  ) {
    return { ok: false, status: 400, message: "Nhập lý do can thiệp." };
  }
  const reason = (json as { reason: string }).reason.trim();
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
  return { ok: true, reason };
}
