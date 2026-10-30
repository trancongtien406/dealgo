import { NextResponse } from "next/server";
import type { OpsUpstreamResult } from "@/lib/api/ops-upstream";

/** Vietnamese copy for cross-cutting Nest error codes (DEC-PROD-044). */
export const OPS_PERMISSION_DENIED_MESSAGE =
  "Vai trò của bạn chưa được cấp quyền cho thao tác này. Liên hệ super-admin nếu cần.";

export function jsonFromOpsUpstream(result: OpsUpstreamResult): NextResponse {
  if (!result.ok) {
    return NextResponse.json(
      {
        success: false,
        message:
          result.errorCode === "OPS_PERMISSION_DENIED"
            ? OPS_PERMISSION_DENIED_MESSAGE
            : result.message,
        ...(result.errorCode ? { errorCode: result.errorCode } : {}),
      },
      { status: result.status },
    );
  }
  return NextResponse.json({
    success: true,
    data: result.data,
    ...(result.requestId ? { requestId: result.requestId } : {}),
  });
}

export function parsePositiveInt(
  value: string | null,
  fallback: number,
  max: number,
): number {
  if (value === null || value === "") {
    return fallback;
  }
  const n = Number(value);
  if (!Number.isSafeInteger(n) || n < 1) {
    return fallback;
  }
  return Math.min(n, max);
}

/** Relays a binary upstream result with no-store caching and no MIME sniffing. */
/**
 * t54u: single `bytes=` range → [start, end] inclusive; null = serve the whole body;
 * "unsatisfiable" = 416. Safari needs 206 range replies to play <video>.
 */
export function parseByteRange(
  header: string | null | undefined,
  size: number,
): [number, number] | null | "unsatisfiable" {
  const match = /^bytes=(\d*)-(\d*)$/.exec(header?.trim() ?? "");
  if (!match || (match[1] === "" && match[2] === "")) {
    return null;
  }
  let start: number;
  let end: number;
  if (match[1] === "") {
    const suffix = Number(match[2]);
    if (suffix === 0) return "unsatisfiable";
    start = Math.max(0, size - suffix);
    end = size - 1;
  } else {
    start = Number(match[1]);
    end = match[2] === "" ? size - 1 : Math.min(Number(match[2]), size - 1);
  }
  if (start >= size || start > end) {
    return "unsatisfiable";
  }
  return [start, end];
}

export function binaryFromOpsUpstream(
  result: import("@/lib/api/ops-upstream").OpsBinaryResult,
  rangeHeader?: string | null,
): Response {
  if (!result.ok) {
    return NextResponse.json(
      { success: false, message: result.message },
      { status: result.status },
    );
  }
  const size = result.body.byteLength;
  const headers: Record<string, string> = {
    "Content-Type": result.contentType,
    "Accept-Ranges": "bytes",
    "Cache-Control": "private, no-store",
    "X-Content-Type-Options": "nosniff",
    "Content-Security-Policy": "default-src 'none'; img-src 'self'; style-src 'unsafe-inline'",
    ...(result.disposition ? { "Content-Disposition": result.disposition } : {}),
  };
  const range = parseByteRange(rangeHeader, size);
  if (range === "unsatisfiable") {
    return new Response(null, {
      status: 416,
      headers: { ...headers, "Content-Range": `bytes */${size}` },
    });
  }
  if (range) {
    const [start, end] = range;
    return new Response(result.body.slice(start, end + 1), {
      status: 206,
      headers: {
        ...headers,
        "Content-Range": `bytes ${start}-${end}/${size}`,
        "Content-Length": String(end - start + 1),
      },
    });
  }
  return new Response(result.body, {
    status: 200,
    headers: { ...headers, "Content-Length": String(size) },
  });
}
