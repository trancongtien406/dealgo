import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { OPS_EVENTS_URL, openOpsEventStream, type EventSourceLike } from "./ops-event-stream";

class FakeES implements EventSourceLike {
  readyState = 0;
  onopen: ((ev: unknown) => void) | null = null;
  onerror: ((ev: unknown) => void) | null = null;
  closed = false;
  listeners = new Map<string, (ev: { data: string }) => void>();
  constructor(public url: string) {}
  addEventListener(type: string, l: (ev: { data: string }) => void) {
    this.listeners.set(type, l);
  }
  close() {
    this.closed = true;
    this.readyState = 2;
  }
  open() {
    this.readyState = 1;
    this.onopen?.({});
  }
  emit(type: string) {
    this.listeners.get(type)?.({ data: "{}" });
  }
  fail(closed: boolean) {
    this.readyState = closed ? 2 : 0;
    this.onerror?.({});
  }
}

function setup() {
  const sources: FakeES[] = [];
  const handlers = { onMonitor: vi.fn(), onSystemErrors: vi.fn(), onReconnect: vi.fn() };
  const close = openOpsEventStream(handlers, (url) => {
    const es = new FakeES(url);
    sources.push(es);
    return es;
  });
  return { sources, handlers, close };
}

describe("openOpsEventStream", () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it("connects to the BFF route and does not refetch on the first open", () => {
    const { sources, handlers, close } = setup();
    expect(sources).toHaveLength(1);
    expect(sources[0]!.url).toBe(OPS_EVENTS_URL);
    sources[0]!.open();
    expect(handlers.onReconnect).not.toHaveBeenCalled();
    close();
  });

  it("routes monitor and systemErrors messages", () => {
    const { sources, handlers, close } = setup();
    sources[0]!.open();
    sources[0]!.emit("monitor");
    sources[0]!.emit("systemErrors");
    sources[0]!.emit("ready");
    expect(handlers.onMonitor).toHaveBeenCalledTimes(1);
    expect(handlers.onSystemErrors).toHaveBeenCalledTimes(1);
    close();
  });

  it("refetches after the browser auto-reconnects", () => {
    const { sources, handlers, close } = setup();
    sources[0]!.open();
    sources[0]!.fail(false);
    sources[0]!.open();
    expect(handlers.onReconnect).toHaveBeenCalledTimes(1);
    expect(sources).toHaveLength(1);
    close();
  });

  it("re-creates a closed stream with backoff, then refetches on reopen", () => {
    const { sources, handlers, close } = setup();
    sources[0]!.open();
    sources[0]!.fail(true);
    expect(sources[0]!.closed).toBe(true);
    vi.advanceTimersByTime(4_999);
    expect(sources).toHaveLength(1);
    vi.advanceTimersByTime(1);
    expect(sources).toHaveLength(2);
    sources[1]!.fail(true);
    vi.advanceTimersByTime(10_000);
    expect(sources).toHaveLength(3);
    sources[2]!.open();
    expect(handlers.onReconnect).toHaveBeenCalledTimes(1);
    close();
  });

  it("cleanup closes the stream and cancels a pending retry", () => {
    const { sources, close } = setup();
    sources[0]!.fail(true);
    expect(vi.getTimerCount()).toBe(1);
    close();
    expect(vi.getTimerCount()).toBe(0);
    vi.advanceTimersByTime(120_000);
    expect(sources).toHaveLength(1);

    const second = setup();
    second.sources[0]!.open();
    second.close();
    expect(second.sources[0]!.closed).toBe(true);
    expect(vi.getTimerCount()).toBe(0);
  });
});
