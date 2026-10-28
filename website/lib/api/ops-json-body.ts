const MAX_BODY_BYTES = 8_192;

/**
 * Reads a small JSON object for BFF routes that forward to Nest as-is.
 * Nest validates fields (whitelist + forbidNonWhitelisted); this only bounds size and shape.
 */
export async function readOpsJsonObject(
  request: Request,
): Promise<
  | { ok: true; body: Record<string, unknown> }
  | { ok: false; status: number; message: string }
> {
  const text = await request.text().catch(() => "");
  if (text.length > MAX_BODY_BYTES) {
    return { ok: false, status: 413, message: "Body quá lớn." };
  }
  try {
    const json: unknown = JSON.parse(text);
    if (json && typeof json === "object" && !Array.isArray(json)) {
      return { ok: true, body: json as Record<string, unknown> };
    }
  } catch {
    // fall through
  }
  return { ok: false, status: 400, message: "Body JSON không hợp lệ." };
}
