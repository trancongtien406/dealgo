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
export function binaryFromOpsUpstream(
  result: import("@/lib/api/ops-upstream").OpsBinaryResult,
): Response {
  if (!result.ok) {
    return NextResponse.json(
      { success: false, message: result.message },
      { status: result.status },
    );
  }
  return new Response(result.body, {
    status: 200,
    headers: {
      "Content-Type": result.contentType,
      "Cache-Control": "private, no-store",
      "X-Content-Type-Options": "nosniff",
      "Content-Security-Policy": "default-src 'none'; img-src 'self'; style-src 'unsafe-inline'",
      ...(result.disposition ? { "Content-Disposition": result.disposition } : {}),
    },
  });
}
