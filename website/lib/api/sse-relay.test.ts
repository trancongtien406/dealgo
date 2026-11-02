import { describe, expect, it } from "vitest";
import { relayUntilUpstreamEnds } from "./sse-relay";

async function readAll(stream: ReadableStream<Uint8Array>) {
  const chunks: string[] = [];
  const reader = stream.getReader();
  for (;;) {
    const { done, value } = await reader.read();
    if (done) return chunks.join("");
    chunks.push(new TextDecoder().decode(value));
  }
}

describe("relayUntilUpstreamEnds", () => {
  it("ends cleanly when the upstream errors mid-stream (DEALGO-WEB-3)", async () => {
    let sent = false;
    const upstream = new ReadableStream<Uint8Array>({
      pull(controller) {
        if (!sent) {
          sent = true;
          controller.enqueue(new TextEncoder().encode("data: hi\n\n"));
        } else {
          controller.error(new Error("socket hang up"));
        }
      },
    });
    await expect(readAll(relayUntilUpstreamEnds(upstream)!)).resolves.toBe("data: hi\n\n");
  });

  it("passes null bodies through", () => {
    expect(relayUntilUpstreamEnds(null)).toBeNull();
  });
});
