import {
  INTERVENE_REASON_MAX,
  INTERVENE_REASON_MIN,
} from "@/lib/api/ops-intervene-body";

export async function readPlatformSettingPatchBody(
  request: Request,
): Promise<
  | { ok: true; value: string; reason: string }
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
  const value = typeof record.value === "string" ? record.value.trim() : "";
  const reason = typeof record.reason === "string" ? record.reason.trim() : "";
  if (value.length === 0 || value.length > 4000) {
    return {
      ok: false,
      status: 400,
      message: "Giá trị cấu hình phải từ 1–4000 ký tự.",
    };
  }
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
  return { ok: true, value, reason };
}
