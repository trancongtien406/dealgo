import { NextResponse } from "next/server";
import { openOpsUpstreamStream } from "@/lib/api/ops-upstream";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

/**
 * Admin live hints: relays Nest GET /v1/ops/events (SSE) using the ops cookie session.
 * The Nest JWT never reaches the browser; closing the EventSource aborts the upstream.
 */
export async function GET(request: Request) {
  const result = await openOpsUpstreamStream("/v1/ops/events", request.signal);
  if (!result.ok) {
    return NextResponse.json(
      { success: false, message: result.message },
      { status: result.status, headers: { "Cache-Control": "no-store" } },
    );
  }
  return new Response(result.upstream.body, {
    status: 200,
    headers: {
      "Content-Type": "text/event-stream; charset=utf-8",
      "Cache-Control": "no-cache, no-transform",
      Connection: "keep-alive",
      "X-Accel-Buffering": "no",
    },
  });
}
