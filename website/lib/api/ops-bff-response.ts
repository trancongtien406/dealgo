import { NextResponse } from "next/server";
import type { OpsUpstreamResult } from "@/lib/api/ops-upstream";

export function jsonFromOpsUpstream(result: OpsUpstreamResult): NextResponse {
  if (!result.ok) {
    return NextResponse.json(
      {
        success: false,
        message: result.message,
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
