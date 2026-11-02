/**
 * When the API restarts (deploy) the upstream body errors mid-stream; Next then logs
 * "failed to pipe response" (Sentry DEALGO-WEB-3). End the relay cleanly instead so the
 * browser's EventSource simply reconnects.
 */
export function relayUntilUpstreamEnds(
  body: ReadableStream<Uint8Array> | null,
): ReadableStream<Uint8Array> | null {
  if (!body) return body;
  const reader = body.getReader();
  return new ReadableStream<Uint8Array>({
    async pull(controller) {
      try {
        const { done, value } = await reader.read();
        if (done) controller.close();
        else controller.enqueue(value);
      } catch {
        controller.close();
      }
    },
    cancel(reason) {
      return reader.cancel(reason).catch(() => undefined);
    },
  });
}
